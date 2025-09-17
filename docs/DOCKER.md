# Docker Containerization

This guide covers the Docker containerization setup for IRC.atl.chat, including container configuration, volumes, networking, security, and best practices.

## Overview

### Architecture

IRC.atl.chat uses Docker Compose for orchestration:

```
Services:
├── unrealircd        - Main IRC server
├── atheme           - IRC services (NickServ, etc.)
├── unrealircd-webpanel - Web administration interface
└── ssl-monitor      - SSL certificate automation
```

### Container Principles

- **Security**: Non-root users, minimal base images
- **Isolation**: Separate containers per service
- **Persistence**: Named volumes for data
- **Networking**: Bridge network with service discovery
- **Health Checks**: Automatic service monitoring

## Container Configuration

### UnrealIRCd Container

#### Build Configuration
```dockerfile
FROM alpine:latest
ARG UNREALIRCD_VERSION=6.2.0.1
ARG UID=1000
ARG GID=1000

# Install dependencies
RUN apk add --no-cache build-base openssl-dev curl-dev zlib-dev \
    libressl-dev ca-certificates git

# Build UnrealIRCd
RUN git clone https://github.com/unrealircd/unrealircd.git && \
    cd unrealircd && \
    git checkout unrealircd-${UNREALIRCD_VERSION} && \
    ./Config && \
    make && make install

# Create user
RUN addgroup -g ${GID} unrealircd && \
    adduser -D -u ${UID} -G unrealircd unrealircd

# Setup directories
RUN mkdir -p /home/unrealircd/unrealircd/conf/tls && \
    chown -R unrealircd:unrealircd /home/unrealircd

USER unrealircd
```

#### Docker Compose Service
```yaml
unrealircd:
  build:
    context: ./src/backend/unrealircd
    dockerfile: Containerfile
    args:
      UNREALIRCD_VERSION: ${UNREALIRCD_VERSION:-6.2.0.1}
      UID: ${PUID:-1000}
      GID: ${PGID:-1000}

  container_name: unrealircd
  hostname: unrealircd
  init: true

  volumes:
    - ./src/backend/unrealircd/conf:/home/unrealircd/unrealircd/conf
    - ./logs/unrealircd:/home/unrealircd/unrealircd/logs
    - ./data/unrealircd:/home/unrealircd/unrealircd/data

  environment:
    - TZ=UTC
    - PUID=${PUID:-1000}
    - PGID=${PGID:-1000}

  ports:
    - '${IRC_TLS_PORT:-6697}:6697'
    - '${IRC_SERVER_PORT:-6900}:6900'
    - '${ATHEME_UPLINK_PORT:-6901}:6901'
    - '${IRC_RPC_PORT:-8600}:8600'
    - '${IRC_WEBSOCKET_PORT:-8000}:8000'

  networks:
    - irc-network

  restart: unless-stopped

  healthcheck:
    test: ['CMD', 'nc', '-z', 'localhost', '6697']
    interval: 30s
    timeout: 10s
    retries: 3
    start_period: 30s

  stop_grace_period: 60s
```

### Atheme Container

#### Network Mode
```yaml
atheme:
  # ... build config ...
  network_mode: service:unrealircd  # Shares network with IRCd
  depends_on:
    unrealircd:
      condition: service_healthy
```

### WebPanel Container

#### Volume Management
```yaml
unrealircd-webpanel:
  # ... config ...
  volumes:
    - unrealircd-webpanel-data:/var/www/html/unrealircd-webpanel/data
```

## Volume Management

### Persistent Volumes

#### Data Volumes
```yaml
volumes:
  unrealircd-webpanel-data:
    name: unrealircd-webpanel-data
    driver: local
```

#### Bind Mounts
```yaml
volumes:
  - ./src/backend/unrealircd/conf:/home/unrealircd/unrealircd/conf
  - ./logs/unrealircd:/home/unrealircd/unrealircd/logs
  - ./data/unrealircd:/home/unrealircd/unrealircd/data
```

### Volume Permissions

#### User Alignment
```bash
# Set PUID/PGID to match host user
export PUID=$(id -u)
export PGID=$(id -g)

# Or set in .env
PUID=1000
PGID=1000
```

#### Permission Fixes
```bash
# Fix permissions after container creation
docker run --rm -v $(pwd)/data:/data alpine chown -R 1000:1000 /data
```

## Networking

### Network Architecture

#### Bridge Network
```yaml
networks:
  irc-network:
    name: irc-network
    driver: bridge
```

#### Service Communication
```
unrealircd (6697) ← IRC clients
    ↓ (6901)
atheme (localhost) ← IRC services
    ↓ (8080)
webpanel ← Admin interface
```

### Port Mapping

#### External Ports
```yaml
ports:
  - '${IRC_TLS_PORT:-6697}:6697'          # IRC over TLS
  - '${IRC_SERVER_PORT:-6900}:6900'       # Server links
  - '${IRC_WEBSOCKET_PORT:-8000}:8000'    # WebSocket IRC
  - '${WEBPANEL_PORT:-8080}:8080'         # WebPanel
```

#### Internal Ports
```yaml
# Atheme uses network_mode, so ports are shared
# IRC_RPC_PORT (8600) - JSON-RPC API (internal)
# ATHEME_UPLINK_PORT (6901) - Services link (localhost)
```

### Network Security

#### Firewall Rules
```bash
# Allow IRC ports
ufw allow 6697/tcp
ufw allow 8080/tcp

# Deny plaintext IRC
ufw deny 6667/tcp
```

#### Container Isolation
```yaml
# Services can't communicate with each other directly
# Only through defined networks and ports
networks:
  - irc-network
```

## Security Best Practices

### Non-Root Containers

#### User Configuration
```dockerfile
# Create non-root user
RUN addgroup -g ${GID} appuser && \
    adduser -D -u ${UID} -G appuser appuser

# Switch to non-root
USER appuser
```

#### Permission Management
```yaml
environment:
  - PUID=${PUID:-1000}
  - PGID=${PGID:-1000}
```

### Image Security

#### Minimal Base Images
```dockerfile
FROM alpine:latest  # Small, secure base

# Install only required packages
RUN apk add --no-cache package1 package2
```

#### Vulnerability Scanning
```bash
# Scan images for vulnerabilities
docker scan unrealircd:latest

# Use trusted base images
FROM alpine:3.18
```

### Secret Management

#### Environment Variables
```yaml
environment:
  - IRC_OPER_PASSWORD=${IRC_OPER_PASSWORD}
  - ATHEME_SEND_PASSWORD=${ATHEME_SEND_PASSWORD}
```

#### External Secrets
```yaml
volumes:
  - ./cloudflare-credentials.ini:/credentials:ro
```

## Health Checks and Monitoring

### Health Check Configuration

#### UnrealIRCd
```yaml
healthcheck:
  test: ['CMD', 'nc', '-z', 'localhost', '6697']
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 30s
```

#### Atheme
```yaml
healthcheck:
  test: ['CMD', 'pgrep', '-f', 'atheme-services']
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 30s
```

#### WebPanel
```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:8080/"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 60s
```

### Monitoring Commands

```bash
# Check container health
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# View container logs
docker logs unrealircd
docker logs -f atheme

# Monitor resource usage
docker stats

# Check container health status
docker inspect unrealircd | grep -A 10 "Health"
```

## Build and Deployment

### Building Images

#### Manual Build
```bash
# Build all services
docker compose build

# Build specific service
docker compose build unrealircd

# Build without cache
docker compose build --no-cache
```

#### Multi-Stage Builds
```dockerfile
# Build stage
FROM alpine:latest AS builder
# Build UnrealIRCd

# Runtime stage
FROM alpine:latest
COPY --from=builder /usr/local/unrealircd /usr/local/unrealircd
```

### Deployment Strategies

#### Rolling Updates
```bash
# Update services without downtime
docker compose up -d --no-deps unrealircd

# Check health after update
docker ps unrealircd
```

#### Blue-Green Deployment
```bash
# Create new stack
docker compose -f docker-compose-green.yml up -d

# Switch traffic (update DNS/load balancer)

# Remove old stack
docker compose down
```

## Troubleshooting

### Common Issues

#### Container Won't Start
```bash
# Check logs
docker logs unrealircd

# Validate configuration
docker run --rm -v $(pwd)/src/backend/unrealircd/conf:/conf \
    unrealircd unrealircd -c /conf/unrealircd.conf

# Check dependencies
docker compose config
```

#### Permission Errors
```bash
# Check file ownership
ls -la data/ logs/

# Fix permissions
sudo chown -R $(id -u):$(id -g) data/ logs/

# Check PUID/PGID
echo "PUID: $(id -u), PGID: $(id -g)"
```

#### Network Issues
```bash
# Check network connectivity
docker network ls

# Inspect network
docker network inspect irc-network

# Test service communication
docker exec unrealircd nc -z localhost 6901
```

#### Performance Problems
```bash
# Monitor resource usage
docker stats

# Check container limits
docker inspect unrealircd | grep -A 10 "Limits"

# Analyze logs for bottlenecks
docker logs unrealircd | grep -i "error\|warning"
```

### Debug Mode

#### Enable Debug Logging
```bash
# Run container with debug
docker run -it --rm unrealircd bash

# Check environment
env | grep PUID

# Test configuration
unrealircd -c /home/unrealircd/unrealircd/conf/unrealircd.conf
```

#### Container Debugging
```bash
# Attach to running container
docker exec -it unrealircd bash

# Check process status
ps aux

# Monitor network connections
netstat -tlnp
```

## Performance Optimization

### Resource Limits

```yaml
deploy:
  resources:
    limits:
      memory: 512M
      cpus: '1.0'
    reservations:
      memory: 256M
      cpus: '0.5'
```

### Image Optimization

#### Multi-Stage Builds
```dockerfile
FROM alpine:latest AS builder
# Build stage

FROM scratch AS runtime
COPY --from=builder /binary /binary
# Minimal runtime image
```

#### Layer Caching
```dockerfile
# Order for better caching
COPY package.json .
RUN npm install
COPY . .
```

### Network Optimization

#### Connection Pooling
```yaml
environment:
  - UV_THREADPOOL_SIZE=4
```

#### Buffer Sizes
```yaml
environment:
  - NODE_OPTIONS=--max-old-space-size=512
```

## Backup and Recovery

### Container Backups

#### Volume Backups
```bash
# Backup named volumes
docker run --rm -v unrealircd-webpanel-data:/data \
    -v $(pwd)/backup:/backup alpine \
    tar czf /backup/webpanel-data.tar.gz -C /data .

# Backup bind mounts
tar czf backup/data-$(date +%Y%m%d).tar.gz data/
tar czf backup/logs-$(date +%Y%m%d).tar.gz logs/
```

#### Image Backups
```bash
# Save images
docker save unrealircd:latest > backup/unrealircd.tar
docker save atheme:latest > backup/atheme.tar

# Load from backup
docker load < backup/unrealircd.tar
```

### Recovery Procedures

#### Full Recovery
```bash
# Stop containers
docker compose down

# Restore volumes
docker run --rm -v unrealircd-webpanel-data:/data \
    -v $(pwd)/backup:/backup alpine \
    tar xzf /backup/webpanel-data.tar.gz -C /data

# Restore data directories
tar xzf backup/data-latest.tar.gz

# Restart services
docker compose up -d
```

#### Partial Recovery
```bash
# Recreate single container
docker compose up -d --no-deps unrealircd

# Restore specific volume
docker run --rm -v specific-volume:/data \
    alpine tar xzf /backup/specific.tar.gz -C /data
```

## Maintenance

### Regular Tasks

```bash
# Update images
docker compose pull

# Clean up unused resources
docker system prune -f

# Rotate logs
./scripts/rotate-logs.sh

# Backup data
./scripts/backup.sh
```

### Monitoring

#### Container Metrics
```bash
# Prometheus metrics (if configured)
curl http://localhost:9090/metrics

# Container stats
docker stats --no-stream

# Log aggregation
docker compose logs -f | tee logs/all-services.log
```

#### Health Monitoring
```bash
# Service health checks
./scripts/health-check.sh

# Certificate monitoring
make ssl-status

# Disk space monitoring
df -h | grep -E "(data|logs)"
```

## Advanced Topics

### Docker Swarm

#### Stack Deployment
```bash
# Deploy to swarm
docker stack deploy -c compose.yaml irc

# Scale services
docker service scale irc_unrealircd=2

# Rolling updates
docker service update --image unrealircd:new irc_unrealircd
```

### Kubernetes

#### Deployment Manifest
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: unrealircd
spec:
  replicas: 1
  selector:
    matchLabels:
      app: unrealircd
  template:
    metadata:
      labels:
        app: unrealircd
    spec:
      containers:
      - name: unrealircd
        image: unrealircd:latest
        ports:
        - containerPort: 6697
```

### CI/CD Integration

#### Automated Builds
```yaml
# GitHub Actions example
- name: Build and push
  uses: docker/build-push-action@v3
  with:
    context: .
    push: true
    tags: unrealircd:latest
```

#### Testing in Containers
```bash
# Run tests in container
docker run --rm -v $(pwd):/app unrealircd make test

# Integration testing
docker compose -f docker-compose.test.yml up --abort-on-container-exit
```

## Related Documentation

- [UNREALIRCD.md](UNREALIRCD.md) - IRC server configuration
- [ATHEME.md](ATHEME.md) - IRC services setup
- [CONFIG.md](CONFIG.md) - Configuration management
- [MAKE.md](MAKE.md) - Build automation
- [Docker Documentation](https://docs.docker.com/) - Official Docker docs
- [Docker Compose](https://docs.docker.com/compose/) - Compose reference
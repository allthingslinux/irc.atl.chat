# Troubleshooting Guide

This comprehensive troubleshooting guide covers common issues and solutions for IRC.atl.chat deployment, configuration, and operation. Use this guide to diagnose and resolve problems efficiently.

## Quick Diagnosis

### System Health Check

Run the comprehensive health check script:

```bash
# Quick environment validation
make test-quick

# Full diagnostic check
./scripts/health-check.sh

# Check all services
make status
```

### Log Analysis

Check service logs for errors:

```bash
# All service logs
make logs

# Specific service logs
make logs-ircd
make logs-atheme
make logs-webpanel

# Follow logs in real-time
make logs-ircd  # Add -f for follow mode
```

## Installation Issues

### Docker Not Available

**Symptoms:**
- `docker: command not found`
- Container operations fail

**Solutions:**

1. **Install Docker:**
   ```bash
   # Ubuntu/Debian
   sudo apt update && sudo apt install docker.io docker-compose-plugin

   # CentOS/RHEL/Fedora
   sudo dnf install docker docker-compose

   # macOS
   brew install docker docker-compose

   # Windows
   # Download from https://docker.com
   ```

2. **Start Docker service:**
   ```bash
   sudo systemctl start docker
   sudo systemctl enable docker
   ```

3. **Add user to docker group:**
   ```bash
   sudo usermod -aG docker $USER
   # Logout and login again, or run: newgrp docker
   ```

4. **Verify installation:**
   ```bash
   docker --version
   docker compose version
   docker run hello-world
   ```

### Permission Denied

**Symptoms:**
- `Permission denied` when accessing files
- Container creation fails

**Common Causes & Solutions:**

1. **File Permissions:**
   ```bash
   # Fix .env file permissions
   chmod 600 .env

   # Fix data directory permissions
   sudo chown -R $(id -u):$(id -g) data/ logs/

   # Check PUID/PGID match host user
   echo "Host user: $(id -u):$(id -g)"
   grep "PUID\|PGID" .env
   ```

2. **Docker Socket Access:**
   ```bash
   # Check socket permissions
   ls -la /var/run/docker.sock

   # Add user to docker group
   sudo usermod -aG docker $USER

   # Or run with sudo (not recommended)
   sudo make up
   ```

### Environment File Missing

**Symptoms:**
- `.env file not found` errors
- Configuration template processing fails

**Solution:**
```bash
# Copy template
cp env.example .env

# Edit with your values
vim .env

# Required variables (minimum):
IRC_DOMAIN=yourdomain.com
IRC_ROOT_DOMAIN=yourdomain.com
LETSENCRYPT_EMAIL=admin@yourdomain.com
```

## Startup Issues

### Services Won't Start

**Symptoms:**
- `make up` hangs or fails
- Containers exit immediately
- Health checks fail

**Diagnostic Steps:**

1. **Check Docker status:**
   ```bash
   docker ps -a
   docker compose ps
   ```

2. **Inspect failed containers:**
   ```bash
   docker logs unrealircd
   docker logs atheme
   docker inspect unrealircd
   ```

3. **Check resource availability:**
   ```bash
   # Memory
   free -h

   # Disk space
   df -h

   # Ports
   netstat -tlnp | grep -E "(6667|6697|6900|6901|8080)"
   ```

**Common Solutions:**

1. **Port conflicts:**
   ```bash
   # Find conflicting processes
   sudo lsof -i :6697

   # Change ports in .env
   IRC_TLS_PORT=6698
   WEBPANEL_PORT=8081
   ```

2. **Memory issues:**
   ```bash
   # Check memory usage
   docker system df

   # Clean up unused resources
   docker system prune -f
   ```

3. **Configuration errors:**
   ```bash
   # Validate .env syntax
   bash -n .env

   # Test configuration processing
   make test-env
   ```

### SSL Certificate Issues

**Symptoms:**
- SSL setup fails
- Certificate validation errors
- TLS connection failures

**SSL Setup Issues:**

1. **Cloudflare credentials missing:**
   ```bash
   # Check credentials file exists
   ls -la cloudflare-credentials.ini

   # Verify format
   cat cloudflare-credentials.ini
   # Should contain: dns_cloudflare_api_token = your-token
   ```

2. **DNS validation fails:**
   ```bash
   # Check DNS records
   dig TXT _acme-challenge.yourdomain.com

   # Verify domain ownership
   whois yourdomain.com
   ```

3. **Certificate generation fails:**
   ```bash
   # Run SSL setup manually
   ./scripts/ssl-manager.sh issue --verbose

   # Check Let's Encrypt logs
   docker logs ssl-monitor
   ```

**Certificate Validation Issues:**

1. **Expired certificates:**
   ```bash
   # Check certificate expiry
   make ssl-status

   # Force renewal
   make ssl-renew
   ```

2. **Certificate chain issues:**
   ```bash
   # Verify certificate chain
   openssl verify -CAfile src/backend/unrealircd/conf/tls/curl-ca-bundle.crt \
                  src/backend/unrealircd/conf/tls/server.cert.pem
   ```

### Atheme Services Not Connecting

**Symptoms:**
- IRC server starts but services don't connect
- NickServ unavailable in IRC
- Services-related errors in logs

**Diagnostic Steps:**

1. **Check service connectivity:**
   ```bash
   # Test local connection
   docker exec unrealircd nc -z localhost 6901

   # Check Atheme logs
   make logs-atheme
   ```

2. **Verify passwords match:**
   ```bash
   # Check .env passwords
   grep -E "(ATHEME_SEND|ATHEME_RECEIVE|IRC_SERVICES)" .env

   # Ensure they're identical
   ```

3. **Check network configuration:**
   ```bash
   # Verify network mode
   docker inspect atheme | grep -A5 "NetworkMode"

   # Should be: "NetworkMode": "container:unrealircd"
   ```

**Solutions:**

1. **Password mismatch:**
   ```bash
   # Generate new passwords
   openssl rand -base64 32

   # Update both in .env
   ATHEME_SEND_PASSWORD=newpassword
   ATHEME_RECEIVE_PASSWORD=newpassword
   ```

2. **Network connectivity:**
   ```bash
   # Restart services in order
   docker restart unrealircd
   sleep 5
   docker restart atheme
   ```

3. **Configuration sync:**
   ```bash
   # Regenerate configurations
   make build
   make restart
   ```

## Runtime Issues

### Connection Problems

**IRC Client Can't Connect:**

1. **Port accessibility:**
   ```bash
   # Test port locally
   telnet localhost 6697

   # Check firewall
   sudo ufw status
   sudo ufw allow 6697/tcp
   ```

2. **SSL/TLS issues:**
   ```bash
   # Test SSL connection
   openssl s_client -connect localhost:6697 -servername yourdomain.com

   # Check certificate
   make ssl-status
   ```

3. **Network configuration:**
   ```bash
   # Verify port mapping
   docker port unrealircd

   # Check Docker network
   docker network ls
   ```

**WebPanel Not Accessible:**

1. **Container status:**
   ```bash
   docker ps | grep webpanel
   make logs-webpanel
   ```

2. **Port conflicts:**
   ```bash
   netstat -tlnp | grep :8080
   # Change port if needed
   WEBPANEL_PORT=8081
   ```

### Performance Issues

**High CPU Usage:**

1. **Monitor resource usage:**
   ```bash
   docker stats
   top -p $(pgrep unrealircd)
   ```

2. **Check connection limits:**
   ```bash
   # Monitor connections
   netstat -antp | grep :6697 | wc -l
   ```

3. **Review configuration:**
   ```bash
   # Check flood protection
   grep -A5 "anti-flood" src/backend/unrealircd/conf/unrealircd.conf
   ```

**High Memory Usage:**

1. **Monitor memory:**
   ```bash
   docker stats --no-stream
   free -h
   ```

2. **Check for memory leaks:**
   ```bash
   # Monitor over time
   watch -n 10 'docker stats --no-stream'
   ```

**Slow Response Times:**

1. **DNS resolution:**
   ```bash
   time nslookup yourdomain.com
   ```

2. **Network latency:**
   ```bash
   ping -c 5 yourdomain.com
   ```

### Database Issues

**Atheme Database Problems:**

1. **Check database file:**
   ```bash
   ls -la data/atheme/atheme.db
   ```

2. **Database integrity:**
   ```bash
   # Inside container
   docker exec atheme sqlite3 /usr/local/atheme/data/atheme.db "PRAGMA integrity_check;"
   ```

3. **Backup and recovery:**
   ```bash
   # Create backup
   cp data/atheme/atheme.db data/atheme/atheme.db.backup

   # Restore from backup
   cp data/atheme/atheme.db.backup data/atheme/atheme.db
   ```

**Channel Database Issues:**

1. **Check UnrealIRCd database:**
   ```bash
   ls -la data/unrealircd/channel.db
   ```

2. **Database corruption:**
   ```bash
   # Restart with fresh database
   rm data/unrealircd/channel.db
   make restart
   ```

### Log Analysis

**Reading Service Logs:**

1. **UnrealIRCd logs:**
   ```bash
   # Current logs
   tail -f logs/unrealircd/ircd.log

   # JSON logs
   tail -f logs/unrealircd/ircd.json.log | jq .

   # Search for errors
   grep -i error logs/unrealircd/ircd.log
   ```

2. **Atheme logs:**
   ```bash
   tail -f logs/atheme/atheme.log
   grep -i "error\|failed" logs/atheme/atheme.log
   ```

3. **WebPanel logs:**
   ```bash
   docker logs unrealircd-webpanel
   ```

**Common Log Patterns:**

- `Connection refused`: Network connectivity issues
- `Permission denied`: File permission problems
- `No such file`: Missing configuration files
- `Certificate verification failed`: SSL certificate issues
- `Authentication failed`: Password or credential problems

## Configuration Issues

### Template Processing Errors

**Symptoms:**
- Configuration files not generated
- Template variables not substituted

**Causes & Solutions:**

1. **Missing environment variables:**
   ```bash
   # Check required variables
   env | grep -E "(IRC_DOMAIN|LETSENCRYPT_EMAIL)"

   # Validate .env file
   ./scripts/prepare-config.sh
   ```

2. **Template syntax errors:**
   ```bash
   # Check template syntax
   head -20 src/backend/unrealircd/conf/unrealircd.conf.template

   # Validate generated config
   unrealircd -c src/backend/unrealircd/conf/unrealircd.conf -t
   ```

### Environment Variable Issues

**Variable not recognized:**

1. **Check variable format:**
   ```bash
   # No spaces around =
   IRC_DOMAIN=yourdomain.com  # Correct
   IRC_DOMAIN = yourdomain.com  # Wrong
   ```

2. **Special characters:**
   ```bash
   # Escape special characters
   PASSWORD='my$password'  # Use quotes
   ```

3. **Variable scope:**
   ```bash
   # Export variables
   export IRC_DOMAIN=yourdomain.com
   make up
   ```

## Security Issues

### Certificate Problems

**SSL Connection Failures:**

1. **Certificate expiry:**
   ```bash
   # Check expiry date
   make ssl-status

   # Renew certificate
   make ssl-renew
   ```

2. **Certificate chain issues:**
   ```bash
   # Verify full chain
   openssl verify -CAfile /etc/ssl/certs/ca-certificates.crt \
                  src/backend/unrealircd/conf/tls/server.cert.pem
   ```

### Access Control Issues

**Unauthorized Access:**

1. **IRC operator permissions:**
   ```bash
   # Check oper block
   grep -A5 "oper yournick" src/backend/unrealircd/conf/unrealircd.conf

   # Verify password hash
   grep "IRC_OPER_PASSWORD" .env
   ```

2. **WebPanel authentication:**
   ```bash
   # Check credentials
   grep "WEBPANEL_RPC" .env
   ```

### Firewall and Network Security

**Blocked Connections:**

1. **Check firewall rules:**
   ```bash
   sudo ufw status
   sudo iptables -L
   ```

2. **Port accessibility:**
   ```bash
   # Test from external host
   telnet yourdomain.com 6697

   # Check DNS
   dig yourdomain.com
   ```

## Docker-Specific Issues

### Container Health Checks

**Unhealthy Containers:**

1. **Check health status:**
   ```bash
   docker ps --format "table {{.Names}}\t{{.Status}}"
   ```

2. **Inspect health checks:**
   ```bash
   docker inspect unrealircd | jq '.[].State.Health'
   ```

3. **Manual health check:**
   ```bash
   # Test IRC connectivity
   echo "PING test" | nc localhost 6697
   ```

### Volume Issues

**Data Persistence Problems:**

1. **Check volume mounts:**
   ```bash
   docker inspect unrealircd | jq '.[].Mounts'
   ```

2. **Verify data directories:**
   ```bash
   ls -la data/ logs/
   ```

3. **Permission issues:**
   ```bash
   # Fix permissions
   sudo chown -R $(id -u):$(id -g) data/ logs/
   ```

### Image Build Issues

**Build Failures:**

1. **Check build logs:**
   ```bash
   docker build --progress=plain -t test .
   ```

2. **Dependency issues:**
   ```bash
   # Check base image
   docker pull alpine:latest
   ```

3. **Cache issues:**
   ```bash
   # Build without cache
   docker build --no-cache -t test .
   ```

## Recovery Procedures

### Emergency Recovery

**Complete System Reset:**

```bash
# WARNING: This destroys all data
make reset

# Fresh installation
cp env.example .env
vim .env  # Configure your settings
make up
```

**Partial Recovery:**

1. **SSL certificate recovery:**
   ```bash
   make ssl-setup
   ```

2. **Database recovery:**
   ```bash
   # Restore from backup
   cp backup/atheme.db data/atheme/atheme.db
   make restart
   ```

3. **Configuration recovery:**
   ```bash
   # Restore .env
   cp backup/.env .env
   make build
   ```

### Backup Strategy

**Regular Backups:**

```bash
# Database backups
cp data/atheme/atheme.db data/atheme/atheme.db.$(date +%Y%m%d)

# Configuration backups
cp .env env.backup.$(date +%Y%m%d)

# Full data backup
tar czf backup/data-$(date +%Y%m%d).tar.gz data/ logs/
```

## Advanced Troubleshooting

### Debug Mode

**Enable Detailed Logging:**

1. **UnrealIRCd debug:**
   ```bash
   # Add to unrealircd.conf
   log "debug.log" {
       source { all; };
       level debug;
   };
   ```

2. **Atheme debug:**
   ```bash
   # Add to atheme.conf
   log {
       file "/usr/local/atheme/logs/debug.log";
       level "debug";
   };
   ```

3. **Docker debug:**
   ```bash
   # Run with debug
   docker run --env DEBUG=1 yourimage
   ```

### Network Debugging

**Connection Analysis:**

```bash
# Packet capture
sudo tcpdump -i any port 6697 -w capture.pcap

# Connection tracking
netstat -antp | grep unrealircd

# DNS debugging
dig +trace yourdomain.com
```

### Performance Profiling

**Resource Monitoring:**

```bash
# System performance
iostat -x 1
vmstat 1

# Application profiling
perf record -p $(pgrep unrealircd) -o perf.data
perf report -i perf.data
```

## Getting Help

### Community Support

1. **Check existing documentation:**
   ```bash
   # Search docs
   grep -r "your-issue" docs/
   ```

2. **GitHub Issues:**
   - Search existing issues
   - Create new issue with logs and configuration

3. **IRC Support:**
   - Join #help on irc.atl.chat
   - Ask in All Things Linux Discord

### Diagnostic Information

**Collect System Information:**

```bash
# System info
uname -a
docker --version
docker compose version

# Service status
make status

# Log excerpts
tail -50 logs/unrealircd/ircd.log
tail -50 logs/atheme/atheme.log

# Configuration summary
grep -E "(VERSION|DOMAIN|PORT)" .env
```

### Error Reporting

**Include in bug reports:**

- Full error messages and stack traces
- Steps to reproduce the issue
- System information (OS, Docker version)
- Configuration files (redact sensitive data)
- Log excerpts from all services
- Output of diagnostic commands

## Prevention

### Best Practices

1. **Regular maintenance:**
   ```bash
   # Weekly checks
   make status
   make ssl-status
   make test-quick
   ```

2. **Backup strategy:**
   ```bash
   # Daily backups
   ./scripts/backup.sh
   ```

3. **Monitoring:**
   ```bash
   # Set up alerts for critical issues
   # Monitor resource usage
   # Regular log review
   ```

4. **Updates:**
   ```bash
   # Keep Docker images updated
   docker compose pull

   # Update configuration templates
   git pull origin main
   ```

This troubleshooting guide covers the most common issues. For complex problems, consider reaching out to the community or creating detailed bug reports with comprehensive diagnostic information.
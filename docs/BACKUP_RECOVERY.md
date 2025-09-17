# Backup & Recovery

This guide covers data backup strategies, disaster recovery procedures, and business continuity planning for IRC.atl.chat.

## Overview

### Backup Philosophy

IRC.atl.chat implements a comprehensive backup strategy based on:

- **3-2-1 Rule**: 3 copies, 2 media types, 1 offsite
- **Automation**: Scheduled, automated backups
- **Testing**: Regular backup validation and restoration testing
- **Security**: Encrypted backups with access controls
- **Monitoring**: Backup success/failure monitoring and alerting

### Data Categories

#### Critical Data (Always Backup)

- **Atheme Database**: User accounts, channel registrations, access lists
- **SSL Certificates**: Private keys and certificate chains
- **Configuration**: Environment variables and custom configurations
- **Channel Data**: Persistent channel information (UnrealIRCd)

#### Operational Data (Backup Recommended)

- **Logs**: Service logs for troubleshooting and compliance
- **User Data**: Uploaded files, custom themes, preferences
- **Metrics**: Performance and usage statistics

#### Temporary Data (Don't Backup)

- **Cache Files**: Temporary caches and session data
- **PID Files**: Process ID files (recreated on startup)
- **Socket Files**: Unix domain sockets

## Backup Strategy

### Automated Daily Backups

#### Schedule and Retention

```bash
# Daily backup schedule
# - Full backup: Sunday at 02:00
# - Incremental: Monday-Saturday at 02:00
# - Retention: 7 daily, 4 weekly, 12 monthly

# Backup verification
# - Integrity checks: Daily
# - Restore testing: Weekly
# - Offsite sync: Hourly
```

#### Backup Components

**Database Backups**

```bash
# Atheme SQLite database backup
backup_atheme_database() {
    local backup_dir="$BACKUP_ROOT/databases"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="$backup_dir/atheme_$timestamp.db"

    # Create backup directory
    mkdir -p "$backup_dir"

    # SQLite backup with integrity check
    if sqlite3 "$ATHEME_DB" ".backup '$backup_file'"; then
        # Verify backup integrity
        if sqlite3 "$backup_file" "PRAGMA integrity_check;" | grep -q "ok"; then
            log_info "Atheme database backup successful: $backup_file"

            # Compress backup
            gzip "$backup_file"
            log_info "Backup compressed: ${backup_file}.gz"

            # Set permissions
            chmod 600 "${backup_file}.gz"

            return 0
        else
            log_error "Backup integrity check failed"
            rm -f "$backup_file"
            return 1
        fi
    else
        log_error "Database backup failed"
        return 1
    fi
}
```

**SSL Certificate Backups**

```bash
# SSL certificate backup
backup_ssl_certificates() {
    local backup_dir="$BACKUP_ROOT/ssl"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="$backup_dir/ssl_$timestamp.tar.gz"

    mkdir -p "$backup_dir"

    # Backup certificate directory
    if tar -czf "$backup_file" \
        -C "$(dirname "$SSL_CERT_DIR")" \
        "$(basename "$SSL_CERT_DIR")"; then

        log_info "SSL certificates backed up: $backup_file"

        # Encrypt backup
        openssl enc -aes-256-cbc -salt \
            -in "$backup_file" \
            -out "${backup_file}.enc" \
            -k "$BACKUP_ENCRYPTION_KEY"

        # Secure encrypted file
        chmod 600 "${backup_file}.enc"
        rm -f "$backup_file"

        log_info "SSL backup encrypted: ${backup_file}.enc"
        return 0
    else
        log_error "SSL certificate backup failed"
        return 1
    fi
}
```

**Configuration Backups**

```bash
# Configuration backup
backup_configuration() {
    local backup_dir="$BACKUP_ROOT/config"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="$backup_dir/config_$timestamp.tar.gz"

    mkdir -p "$backup_dir"

    # Backup configuration files
    if tar -czf "$backup_file" \
        --exclude='*.log' \
        --exclude='*.pid' \
        --exclude='*.sock' \
        -C "$PROJECT_ROOT" \
        .env \
        src/backend/*/conf/*.conf \
        docs/; then

        log_info "Configuration backed up: $backup_file"
        chmod 600 "$backup_file"
        return 0
    else
        log_error "Configuration backup failed"
        return 1
    fi
}
```

### Backup Storage

#### Local Storage

```bash
# Local backup directory structure
backup/
├── databases/
│   ├── atheme_20231201_020000.db.gz
│   └── atheme_20231202_020000.db.gz
├── ssl/
│   ├── ssl_20231201_020000.tar.gz.enc
│   └── ssl_20231202_020000.tar.gz.enc
├── config/
│   ├── config_20231201_020000.tar.gz
│   └── config_20231202_020000.tar.gz
└── logs/
    └── backup.log
```

#### Remote Storage (Recommended)

```bash
# Remote backup synchronization
sync_to_remote() {
    local remote_host="backup.example.com"
    local remote_path="/backups/irc-atl-chat"

    # Sync using rsync with SSH
    rsync -avz --delete \
        --exclude='*.log' \
        -e "ssh -i $SSH_KEY" \
        "$BACKUP_ROOT/" \
        "$remote_host:$remote_path/"

    if [[ $? -eq 0 ]]; then
        log_info "Remote backup sync successful"
        return 0
    else
        log_error "Remote backup sync failed"
        return 1
    fi
}
```

#### Cloud Storage

```bash
# Cloud backup using rclone
backup_to_cloud() {
    local cloud_provider="s3"
    local bucket="irc-atl-chat-backups"

    # Upload to cloud storage
    rclone copy "$BACKUP_ROOT" "$cloud_provider:$bucket"

    if [[ $? -eq 0 ]]; then
        log_info "Cloud backup upload successful"
        return 0
    else
        log_error "Cloud backup upload failed"
        return 1
    fi
}
```

### Backup Encryption

#### Encryption Setup

```bash
# Generate encryption key
BACKUP_ENCRYPTION_KEY=$(openssl rand -base64 32)

# Store securely (environment variable or key file)
echo "BACKUP_ENCRYPTION_KEY=$BACKUP_ENCRYPTION_KEY" >> .env.backup
chmod 600 .env.backup
```

#### Encryption Verification

```bash
# Test encryption/decryption
test_encryption() {
    local test_file="/tmp/test_backup.txt"
    local encrypted_file="/tmp/test_backup.txt.enc"

    echo "Test backup data" > "$test_file"

    # Encrypt
    openssl enc -aes-256-cbc -salt \
        -in "$test_file" \
        -out "$encrypted_file" \
        -k "$BACKUP_ENCRYPTION_KEY"

    # Decrypt and verify
    local decrypted_content
    decrypted_content=$(openssl enc -d -aes-256-cbc \
        -in "$encrypted_file" \
        -k "$BACKUP_ENCRYPTION_KEY")

    if [[ "$decrypted_content" == "Test backup data" ]]; then
        log_info "Encryption test passed"
        return 0
    else
        log_error "Encryption test failed"
        return 1
    fi
}
```

## Recovery Procedures

### Emergency Recovery

#### Complete System Recovery

```bash
# 1. Stop all services
make down

# 2. Identify latest backups
ls -la backup/databases/ | tail -5
ls -la backup/ssl/ | tail -5
ls -la backup/config/ | tail -5

# 3. Restore configuration
tar -xzf backup/config/config_latest.tar.gz -C /

# 4. Restore SSL certificates
openssl enc -d -aes-256-cbc \
    -in backup/ssl/ssl_latest.tar.gz.enc \
    -out /tmp/ssl_backup.tar.gz \
    -k "$BACKUP_ENCRYPTION_KEY"

tar -xzf /tmp/ssl_backup.tar.gz -C /

# 5. Restore database
gunzip -c backup/databases/atheme_latest.db.gz > data/atheme/atheme.db

# 6. Restart services
make up

# 7. Verify recovery
make status
make health-check
```

#### Database Recovery

```bash
# SQLite database recovery
recover_database() {
    local backup_file="$1"
    local target_db="$2"

    log_info "Starting database recovery from $backup_file"

    # Stop services using database
    docker stop atheme

    # Create backup of current database
    cp "$target_db" "${target_db}.pre_recovery"

    # Restore from backup
    if gunzip -c "$backup_file" > "$target_db"; then
        # Verify database integrity
        if sqlite3 "$target_db" "PRAGMA integrity_check;" | grep -q "ok"; then
            log_info "Database recovery successful"

            # Start services
            docker start atheme

            # Clean up
            rm -f "${target_db}.pre_recovery"

            return 0
        else
            log_error "Database integrity check failed after recovery"
            # Restore from pre-recovery backup
            mv "${target_db}.pre_recovery" "$target_db"
            return 1
        fi
    else
        log_error "Database extraction failed"
        return 1
    fi
}
```

#### SSL Certificate Recovery

```bash
# SSL certificate recovery
recover_ssl_certificates() {
    local backup_file="$1"
    local ssl_dir="$2"

    log_info "Starting SSL certificate recovery"

    # Stop services using SSL
    docker stop unrealircd unrealircd-webpanel

    # Decrypt backup
    openssl enc -d -aes-256-cbc \
        -in "$backup_file" \
        -out /tmp/ssl_recovery.tar.gz \
        -k "$BACKUP_ENCRYPTION_KEY"

    # Extract certificates
    rm -rf "$ssl_dir"  # Remove current certificates
    mkdir -p "$ssl_dir"

    if tar -xzf /tmp/ssl_recovery.tar.gz -C "$(dirname "$ssl_dir")"; then
        # Set correct permissions
        chmod 644 "$ssl_dir"/*.pem
        chmod 755 "$ssl_dir"

        # Start services
        docker start unrealircd unrealircd-webpanel

        # Clean up
        rm -f /tmp/ssl_recovery.tar.gz

        log_info "SSL certificate recovery successful"
        return 0
    else
        log_error "SSL certificate extraction failed"
        return 1
    fi
}
```

### Partial Recovery

#### User Account Recovery

```bash
# Recover specific user account
recover_user_account() {
    local username="$1"
    local backup_db="$2"

    log_info "Recovering user account: $username"

    # Extract user data from backup
    sqlite3 "$backup_db" << EOF
.mode csv
.header on
.output /tmp/user_${username}.csv
SELECT * FROM nick_table WHERE nick = '$username';
SELECT * FROM account_table WHERE name = '$username';
EOF

    # Import into current database
    sqlite3 data/atheme/atheme.db << EOF
.mode csv
.import /tmp/user_${username}.csv temp_recovery
INSERT OR REPLACE INTO nick_table SELECT * FROM temp_recovery;
INSERT OR REPLACE INTO account_table SELECT * FROM temp_recovery;
DROP TABLE temp_recovery;
EOF

    # Clean up
    rm -f "/tmp/user_${username}.csv"

    log_info "User account recovery completed"
}
```

#### Channel Recovery

```bash
# Recover channel registration
recover_channel() {
    local channel="$1"
    local backup_db="$2"

    log_info "Recovering channel: $channel"

    # Extract channel data from backup
    sqlite3 "$backup_db" << EOF
.mode csv
.header on
.output /tmp/channel_${channel}.csv
SELECT * FROM chan_table WHERE chan = '$channel';
SELECT * FROM chanacs_table WHERE chan = '$channel';
EOF

    # Import into current database
    sqlite3 data/atheme/atheme.db << EOF
.mode csv
.import /tmp/channel_${channel}.csv temp_recovery
INSERT OR REPLACE INTO chan_table SELECT * FROM temp_recovery;
INSERT OR REPLACE INTO chanacs_table SELECT * FROM temp_recovery;
DROP TABLE temp_recovery;
EOF

    # Clean up
    rm -f "/tmp/channel_${channel}.csv"

    log_info "Channel recovery completed"
}
```

## Business Continuity

### Service Level Objectives

#### Recovery Time Objective (RTO)

- **Critical Services**: RTO < 1 hour
- **User Services**: RTO < 4 hours
- **Full System**: RTO < 24 hours

#### Recovery Point Objective (RPO)

- **User Data**: RPO < 1 hour
- **Channel Data**: RPO < 1 hour
- **Configuration**: RPO < 24 hours

### High Availability Setup

#### Database Replication

```bash
# Atheme database replication setup
setup_database_replication() {
    # Primary database
    PRIMARY_DB="data/atheme/atheme.db"

    # Replica database
    REPLICA_DB="data/atheme/atheme-replica.db"

    # Copy database for replication
    cp "$PRIMARY_DB" "$REPLICA_DB"

    # Set up WAL mode for replication
    sqlite3 "$PRIMARY_DB" "PRAGMA journal_mode=WAL;"
    sqlite3 "$REPLICA_DB" "PRAGMA journal_mode=WAL;"
}
```

#### Service Redundancy

```yaml
# Docker Compose with redundancy
services:
  unrealircd-primary:
    # Primary IRC server
  unrealircd-secondary:
    # Secondary IRC server
  atheme-primary:
    # Primary services
  atheme-secondary:
    # Secondary services
  load-balancer:
    # Load balancer for redundancy
```

### Disaster Recovery Plan

#### Emergency Response

1. **Assess Situation**
   - Determine scope of incident
   - Identify affected services
   - Notify stakeholders

2. **Activate Recovery**
   - Execute appropriate recovery procedure
   - Monitor recovery progress
   - Communicate status updates

3. **Verify Recovery**
   - Test service functionality
   - Validate data integrity
   - Confirm user access

4. **Post-Incident Review**
   - Document incident and response
   - Identify improvement opportunities
   - Update recovery procedures

#### Communication Plan

```bash
# Emergency notification
notify_emergency() {
    local message="$1"
    local severity="${2:-info}"

    # IRC notification
    echo "$message" | nc localhost 6697

    # Email notification
    echo "$message" | mail -s "IRC.atl.chat $severity" admin@atl.chat

    # Slack/Discord notification (if configured)
    curl -X POST "$WEBHOOK_URL" \
        -H 'Content-type: application/json' \
        -d "{\"text\":\"IRC.atl.chat $severity: $message\"}"
}
```

## Backup Monitoring

### Backup Health Checks

#### Daily Verification

```bash
# Backup integrity check
verify_backups() {
    local backup_root="$1"

    # Check backup directories exist
    for dir in databases ssl config; do
        if [[ ! -d "$backup_root/$dir" ]]; then
            log_error "Backup directory missing: $backup_root/$dir"
            return 1
        fi
    done

    # Check recent backups exist
    local recent_db_backup
    recent_db_backup=$(find "$backup_root/databases" -name "*.db.gz" -mtime -1 | wc -l)

    if [[ $recent_db_backup -eq 0 ]]; then
        log_error "No recent database backup found"
        return 1
    fi

    # Verify backup sizes are reasonable
    local db_size
    db_size=$(stat -f%z "$backup_root/databases/$(ls -t "$backup_root/databases/" | head -1)" 2>/dev/null || echo "0")

    if [[ $db_size -lt 1024 ]]; then  # Less than 1KB
        log_error "Database backup suspiciously small: $db_size bytes"
        return 1
    fi

    log_info "Backup verification passed"
    return 0
}
```

#### Automated Monitoring

```bash
# Cron job for backup monitoring
# Add to crontab: crontab -e
# 0 6 * * * /path/to/irc-atl-chat/scripts/verify-backups.sh

#!/bin/bash
# verify-backups.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Source environment
if [[ -f "$PROJECT_ROOT/.env" ]]; then
    source "$PROJECT_ROOT/.env"
fi

# Run verification
if ! verify_backups "$BACKUP_ROOT"; then
    echo "Backup verification failed at $(date)" | mail -s "Backup Alert" "$ADMIN_EMAIL"
    exit 1
fi

echo "Backup verification successful at $(date)"
```

### Backup Metrics

#### Monitoring Integration

```bash
# Prometheus metrics for backups
generate_backup_metrics() {
    local metrics_file="/tmp/backup_metrics.prom"

    cat > "$metrics_file" << EOF
# HELP backup_last_success_timestamp Timestamp of last successful backup
# TYPE backup_last_success_timestamp gauge
backup_last_success_timestamp $(stat -c %Y "$BACKUP_ROOT/databases/$(ls -t "$BACKUP_ROOT/databases/" | head -1)" 2>/dev/null || echo "0")

# HELP backup_database_size_bytes Size of latest database backup
# TYPE backup_database_size_bytes gauge
backup_database_size_bytes $(stat -c %s "$BACKUP_ROOT/databases/$(ls -t "$BACKUP_ROOT/databases/" | head -1)" 2>/dev/null || echo "0")

# HELP backup_ssl_size_bytes Size of latest SSL backup
# TYPE backup_ssl_size_bytes gauge
backup_ssl_size_bytes $(stat -c %s "$BACKUP_ROOT/ssl/$(ls -t "$BACKUP_ROOT/ssl/" | head -1)" 2>/dev/null || echo "0")
EOF

    # Expose metrics
    cp "$metrics_file" /var/lib/prometheus/backup_metrics.prom
}
```

## Testing and Validation

### Backup Testing

#### Regular Restore Testing

```bash
# Monthly restore test
test_backup_restore() {
    local test_env="/tmp/irc_restore_test"

    log_info "Starting backup restore test"

    # Create test environment
    mkdir -p "$test_env"
    cd "$test_env"

    # Copy latest backups
    cp "$BACKUP_ROOT/databases/$(ls -t "$BACKUP_ROOT/databases/" | head -1)" ./test.db.gz
    cp "$BACKUP_ROOT/config/$(ls -t "$BACKUP_ROOT/config/" | head -1)" ./test_config.tar.gz

    # Test database extraction
    if ! gunzip -c test.db.gz > test.db; then
        log_error "Database extraction test failed"
        return 1
    fi

    # Test database integrity
    if ! sqlite3 test.db "PRAGMA integrity_check;" | grep -q "ok"; then
        log_error "Database integrity test failed"
        return 1
    fi

    # Test configuration extraction
    if ! tar -tzf test_config.tar.gz >/dev/null; then
        log_error "Configuration extraction test failed"
        return 1
    fi

    # Clean up
    cd - >/dev/null
    rm -rf "$test_env"

    log_info "Backup restore test passed"
    return 0
}
```

#### Performance Testing

```bash
# Backup performance monitoring
monitor_backup_performance() {
    local start_time
    local end_time
    local duration

    start_time=$(date +%s)

    # Run backup
    if backup_all; then
        end_time=$(date +%s)
        duration=$((end_time - start_time))

        # Log performance
        echo "$(date): Backup completed in ${duration}s" >> "$BACKUP_ROOT/performance.log"

        # Alert if too slow (more than 300 seconds)
        if [[ $duration -gt 300 ]]; then
            notify_admin "Backup performance warning: ${duration}s"
        fi

        return 0
    else
        log_error "Backup failed"
        return 1
    fi
}
```

## Compliance and Auditing

### Audit Logging

#### Backup Operations Audit

```bash
# Audit all backup operations
audit_backup_operation() {
    local operation="$1"
    local result="$2"
    local details="$3"

    echo "$(date +%Y-%m-%dT%H:%M:%S)|BACKUP|$operation|$result|$USER|$details" >> "$BACKUP_ROOT/audit.log"
}

# Usage
audit_backup_operation "database_backup" "success" "atheme_20231201.db.gz"
audit_backup_operation "ssl_backup" "failed" "encryption_error"
```

### Compliance Requirements

#### Data Retention

```bash
# Automated cleanup of old backups
cleanup_old_backups() {
    local retention_days="${1:-30}"

    log_info "Cleaning up backups older than $retention_days days"

    # Remove old database backups
    find "$BACKUP_ROOT/databases" -name "*.db.gz" -mtime +$retention_days -delete

    # Remove old SSL backups
    find "$BACKUP_ROOT/ssl" -name "*.enc" -mtime +$retention_days -delete

    # Remove old config backups
    find "$BACKUP_ROOT/config" -name "*.tar.gz" -mtime +$retention_days -delete

    log_info "Backup cleanup completed"
}
```

#### Access Controls

```bash
# Secure backup directory permissions
secure_backup_permissions() {
    # Set restrictive permissions
    chmod 700 "$BACKUP_ROOT"
    chmod 600 "$BACKUP_ROOT"/*/*
    chown -R backup:backup "$BACKUP_ROOT"

    # Audit permission changes
    audit_backup_operation "permission_fix" "success" "secured_backup_permissions"
}
```

## Maintenance Procedures

### Regular Maintenance

#### Weekly Tasks

```bash
# Weekly backup verification
verify_backups "$BACKUP_ROOT"

# Test restore procedures
test_backup_restore

# Check backup storage usage
du -sh "$BACKUP_ROOT"
```

#### Monthly Tasks

```bash
# Full system backup test
test_full_system_restore

# Review backup retention policies
review_backup_retention

# Update backup encryption keys (if needed)
rotate_backup_keys
```

#### Quarterly Tasks

```bash
# Disaster recovery drill
conduct_disaster_recovery_drill

# Review backup procedures
review_backup_documentation

# Update recovery plans
update_recovery_procedures
```

### Backup System Updates

#### Software Updates

```bash
# Update backup tools
update_backup_tools() {
    # Update rclone for cloud backups
    curl -fsSL https://rclone.org/install.sh | bash

    # Update encryption tools
    apt-get update && apt-get install openssl sqlite3

    audit_backup_operation "software_update" "success" "backup_tools_updated"
}
```

#### Monitoring Updates

```bash
# Update monitoring configuration
update_backup_monitoring() {
    # Update Prometheus configuration
    cat > /etc/prometheus/backup.yml << EOF
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'backup_metrics'
    static_configs:
      - targets: ['localhost:9090']
EOF

    # Reload Prometheus
    systemctl reload prometheus

    audit_backup_operation "monitoring_update" "success" "prometheus_config_updated"
}
```

## Summary

### Backup Strategy Summary

- **Daily automated backups** of critical data
- **Multi-location storage** (local, remote, cloud)
- **Encryption** for sensitive data
- **Integrity verification** of all backups
- **Regular testing** of restore procedures
- **Monitoring and alerting** for backup failures

### Recovery Capabilities

- **RTO**: < 1 hour for critical services
- **RPO**: < 1 hour for user data
- **Automated procedures** for common scenarios
- **Manual procedures** for complex recoveries
- **Testing and validation** of recovery processes

### Business Continuity

- **High availability options** for critical deployments
- **Disaster recovery plans** with clear procedures
- **Communication plans** for incident response
- **Regular drills** to maintain readiness

This comprehensive backup and recovery system ensures IRC.atl.chat can maintain service continuity and data integrity even in adverse conditions.
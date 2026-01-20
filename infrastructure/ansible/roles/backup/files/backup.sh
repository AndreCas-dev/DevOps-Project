#!/bin/bash
#
# Backup script for DevOps Project
# Backs up PostgreSQL database and Docker volumes
#

set -euo pipefail

# Configuration
BACKUP_DIR="${BACKUP_DIR:-/var/backups/devops}"
RETENTION_DAYS="${RETENTION_DAYS:-7}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="backup_${TIMESTAMP}"

# Database configuration
POSTGRES_CONTAINER="${POSTGRES_CONTAINER:-db}"
POSTGRES_USER="${POSTGRES_USER:-postgres}"
POSTGRES_DB="${POSTGRES_DB:-Test}"

# Docker compose directory
COMPOSE_DIR="${COMPOSE_DIR:-/opt/devops-app/docker}"

# Volumes to backup
VOLUMES_DIR="${VOLUMES_DIR:-/opt/devops-app/volumes}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Options:
    -t, --type TYPE     Backup type: all, database, volumes (default: all)
    -d, --dir DIR       Backup directory (default: /var/backups/devops)
    -r, --retention N   Retention days (default: 7)
    -h, --help          Show this help message

Examples:
    $0                      # Full backup
    $0 -t database          # Database only
    $0 -t volumes           # Volumes only
    $0 -d /custom/path      # Custom backup directory
EOF
    exit 0
}

# Parse arguments
BACKUP_TYPE="all"

while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--type)
            BACKUP_TYPE="$2"
            shift 2
            ;;
        -d|--dir)
            BACKUP_DIR="$2"
            shift 2
            ;;
        -r|--retention)
            RETENTION_DAYS="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            ;;
    esac
done

# Create backup directory
create_backup_dir() {
    local backup_path="${BACKUP_DIR}/${BACKUP_NAME}"
    mkdir -p "${backup_path}"
    echo "${backup_path}"
}

# Backup PostgreSQL database
backup_database() {
    local backup_path="$1"
    local db_backup_file="${backup_path}/postgres_${POSTGRES_DB}_${TIMESTAMP}.sql.gz"

    log_info "Starting PostgreSQL backup..."

    if ! docker ps --format '{{.Names}}' | grep -q "^${POSTGRES_CONTAINER}$"; then
        log_error "PostgreSQL container '${POSTGRES_CONTAINER}' is not running"
        return 1
    fi

    docker exec "${POSTGRES_CONTAINER}" pg_dump -U "${POSTGRES_USER}" "${POSTGRES_DB}" | gzip > "${db_backup_file}"

    if [[ -f "${db_backup_file}" ]]; then
        local size=$(du -h "${db_backup_file}" | cut -f1)
        log_info "Database backup completed: ${db_backup_file} (${size})"
    else
        log_error "Database backup failed"
        return 1
    fi
}

# Backup Docker volumes
backup_volumes() {
    local backup_path="$1"
    local volumes_backup="${backup_path}/volumes"

    mkdir -p "${volumes_backup}"

    log_info "Starting volumes backup..."

    # List of volumes to backup
    local volumes=("prometheus-data" "grafana-data" "alertmanager-data" "loki-data")

    for vol in "${volumes[@]}"; do
        local vol_path="${VOLUMES_DIR}/${vol}"
        if [[ -d "${vol_path}" ]]; then
            log_info "Backing up volume: ${vol}"
            tar -czf "${volumes_backup}/${vol}_${TIMESTAMP}.tar.gz" -C "${VOLUMES_DIR}" "${vol}" 2>/dev/null || {
                log_warn "Could not backup ${vol} - directory might be empty or inaccessible"
            }
        else
            log_warn "Volume directory not found: ${vol_path}"
        fi
    done

    # Backup PostgreSQL data volume using Docker
    log_info "Backing up PostgreSQL data volume..."
    docker run --rm \
        -v postgres_data:/data:ro \
        -v "${volumes_backup}":/backup \
        alpine:latest \
        tar -czf "/backup/postgres_data_${TIMESTAMP}.tar.gz" -C /data . 2>/dev/null || {
        log_warn "Could not backup postgres_data volume"
    }

    log_info "Volumes backup completed"
}

# Backup configuration files
backup_configs() {
    local backup_path="$1"
    local config_backup="${backup_path}/configs"

    mkdir -p "${config_backup}"

    log_info "Starting configuration backup..."

    # Backup docker-compose files
    if [[ -d "${COMPOSE_DIR}" ]]; then
        cp -r "${COMPOSE_DIR}"/*.yml "${config_backup}/" 2>/dev/null || true
    fi

    # Backup monitoring configs
    local monitoring_dir="${COMPOSE_DIR}/../monitoring"
    if [[ -d "${monitoring_dir}" ]]; then
        tar -czf "${config_backup}/monitoring_config_${TIMESTAMP}.tar.gz" -C "${monitoring_dir}/.." monitoring 2>/dev/null || {
            log_warn "Could not backup monitoring configs"
        }
    fi

    # Backup logging configs
    local logging_dir="${COMPOSE_DIR}/../logging"
    if [[ -d "${logging_dir}" ]]; then
        tar -czf "${config_backup}/logging_config_${TIMESTAMP}.tar.gz" -C "${logging_dir}/.." logging 2>/dev/null || {
            log_warn "Could not backup logging configs"
        }
    fi

    log_info "Configuration backup completed"
}

# Clean old backups
cleanup_old_backups() {
    log_info "Cleaning backups older than ${RETENTION_DAYS} days..."

    find "${BACKUP_DIR}" -maxdepth 1 -type d -name "backup_*" -mtime +${RETENTION_DAYS} -exec rm -rf {} \; 2>/dev/null || true

    local remaining=$(find "${BACKUP_DIR}" -maxdepth 1 -type d -name "backup_*" | wc -l)
    log_info "Cleanup completed. Remaining backups: ${remaining}"
}

# Create backup manifest
create_manifest() {
    local backup_path="$1"
    local manifest="${backup_path}/manifest.txt"

    cat > "${manifest}" << EOF
Backup Manifest
===============
Date: $(date)
Hostname: $(hostname)
Backup Type: ${BACKUP_TYPE}
Backup Name: ${BACKUP_NAME}

Contents:
$(find "${backup_path}" -type f -exec ls -lh {} \;)

Database Info:
- Container: ${POSTGRES_CONTAINER}
- Database: ${POSTGRES_DB}
- User: ${POSTGRES_USER}
EOF

    log_info "Manifest created: ${manifest}"
}

# Main function
main() {
    log_info "=========================================="
    log_info "Starting backup process"
    log_info "Backup type: ${BACKUP_TYPE}"
    log_info "Backup directory: ${BACKUP_DIR}"
    log_info "=========================================="

    # Create backup directory
    local backup_path
    backup_path=$(create_backup_dir)

    case "${BACKUP_TYPE}" in
        all)
            backup_database "${backup_path}"
            backup_volumes "${backup_path}"
            backup_configs "${backup_path}"
            ;;
        database)
            backup_database "${backup_path}"
            ;;
        volumes)
            backup_volumes "${backup_path}"
            backup_configs "${backup_path}"
            ;;
        *)
            log_error "Invalid backup type: ${BACKUP_TYPE}"
            exit 1
            ;;
    esac

    # Create manifest
    create_manifest "${backup_path}"

    # Cleanup old backups
    cleanup_old_backups

    local total_size=$(du -sh "${backup_path}" | cut -f1)

    log_info "=========================================="
    log_info "Backup completed successfully!"
    log_info "Location: ${backup_path}"
    log_info "Total size: ${total_size}"
    log_info "=========================================="
}

# Run main
main

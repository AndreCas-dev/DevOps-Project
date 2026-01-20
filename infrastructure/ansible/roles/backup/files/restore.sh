#!/bin/bash
#
# Restore script for DevOps Project
# Restores PostgreSQL database and Docker volumes from backup
#

set -euo pipefail

# Configuration
BACKUP_DIR="${BACKUP_DIR:-/var/backups/devops}"

# Database configuration
POSTGRES_CONTAINER="${POSTGRES_CONTAINER:-db}"
POSTGRES_USER="${POSTGRES_USER:-postgres}"
POSTGRES_DB="${POSTGRES_DB:-Test}"

# Docker compose directory
COMPOSE_DIR="${COMPOSE_DIR:-/opt/devops-app/docker}"

# Volumes directory
VOLUMES_DIR="${VOLUMES_DIR:-/opt/devops-app/volumes}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
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

log_step() {
    echo -e "${CYAN}[STEP]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Options:
    -b, --backup NAME   Backup name to restore (required unless using -l)
    -t, --type TYPE     Restore type: all, database, volumes (default: all)
    -d, --dir DIR       Backup directory (default: /var/backups/devops)
    -l, --list          List available backups
    -f, --force         Skip confirmation prompts
    -h, --help          Show this help message

Examples:
    $0 -l                           # List available backups
    $0 -b backup_20240115_020000    # Restore specific backup
    $0 -b backup_20240115_020000 -t database  # Restore database only
    $0 -b backup_20240115_020000 -f # Restore without confirmation
EOF
    exit 0
}

# List available backups
list_backups() {
    log_info "Available backups in ${BACKUP_DIR}:"
    echo ""

    if [[ ! -d "${BACKUP_DIR}" ]]; then
        log_error "Backup directory not found: ${BACKUP_DIR}"
        exit 1
    fi

    local backups
    backups=$(find "${BACKUP_DIR}" -maxdepth 1 -type d -name "backup_*" | sort -r)

    if [[ -z "${backups}" ]]; then
        log_warn "No backups found"
        exit 0
    fi

    printf "%-30s %-15s %-20s\n" "BACKUP NAME" "SIZE" "DATE"
    printf "%s\n" "--------------------------------------------------------------"

    for backup in ${backups}; do
        local name=$(basename "${backup}")
        local size=$(du -sh "${backup}" 2>/dev/null | cut -f1)
        local date=$(stat -c %y "${backup}" 2>/dev/null | cut -d'.' -f1)
        printf "%-30s %-15s %-20s\n" "${name}" "${size}" "${date}"
    done

    echo ""
}

# Confirm restore
confirm_restore() {
    local backup_name="$1"

    if [[ "${FORCE}" == "true" ]]; then
        return 0
    fi

    echo ""
    log_warn "WARNING: This will restore data from backup '${backup_name}'"
    log_warn "Current data will be OVERWRITTEN!"
    echo ""

    read -p "Are you sure you want to continue? (yes/no): " confirm

    if [[ "${confirm}" != "yes" ]]; then
        log_info "Restore cancelled"
        exit 0
    fi
}

# Restore PostgreSQL database
restore_database() {
    local backup_path="$1"

    log_step "Restoring PostgreSQL database..."

    # Find database backup file
    local db_backup
    db_backup=$(find "${backup_path}" -name "postgres_*.sql.gz" | head -1)

    if [[ -z "${db_backup}" ]]; then
        log_error "Database backup file not found in ${backup_path}"
        return 1
    fi

    log_info "Found database backup: ${db_backup}"

    # Check if container is running
    if ! docker ps --format '{{.Names}}' | grep -q "^${POSTGRES_CONTAINER}$"; then
        log_error "PostgreSQL container '${POSTGRES_CONTAINER}' is not running"
        log_info "Please start the container first: docker compose up -d db"
        return 1
    fi

    # Drop and recreate database
    log_info "Dropping and recreating database..."
    docker exec "${POSTGRES_CONTAINER}" psql -U "${POSTGRES_USER}" -c "DROP DATABASE IF EXISTS ${POSTGRES_DB};" || true
    docker exec "${POSTGRES_CONTAINER}" psql -U "${POSTGRES_USER}" -c "CREATE DATABASE ${POSTGRES_DB};"

    # Restore database
    log_info "Restoring database from backup..."
    gunzip -c "${db_backup}" | docker exec -i "${POSTGRES_CONTAINER}" psql -U "${POSTGRES_USER}" "${POSTGRES_DB}"

    log_info "Database restore completed"
}

# Restore Docker volumes
restore_volumes() {
    local backup_path="$1"
    local volumes_backup="${backup_path}/volumes"

    if [[ ! -d "${volumes_backup}" ]]; then
        log_warn "Volumes backup directory not found: ${volumes_backup}"
        return 0
    fi

    log_step "Restoring Docker volumes..."

    # Stop services that use these volumes
    log_info "Stopping services..."
    cd "${COMPOSE_DIR}" && docker compose stop prometheus grafana alertmanager loki 2>/dev/null || true

    # Restore each volume
    local volumes=("prometheus-data" "grafana-data" "alertmanager-data" "loki-data")

    for vol in "${volumes[@]}"; do
        local vol_backup
        vol_backup=$(find "${volumes_backup}" -name "${vol}_*.tar.gz" | head -1)

        if [[ -n "${vol_backup}" ]]; then
            log_info "Restoring volume: ${vol}"
            rm -rf "${VOLUMES_DIR}/${vol}"
            mkdir -p "${VOLUMES_DIR}"
            tar -xzf "${vol_backup}" -C "${VOLUMES_DIR}"
        else
            log_warn "Backup not found for volume: ${vol}"
        fi
    done

    # Restore PostgreSQL data volume
    local pg_vol_backup
    pg_vol_backup=$(find "${volumes_backup}" -name "postgres_data_*.tar.gz" | head -1)

    if [[ -n "${pg_vol_backup}" ]]; then
        log_info "Restoring PostgreSQL data volume..."

        # Stop database container
        docker stop "${POSTGRES_CONTAINER}" 2>/dev/null || true

        docker run --rm \
            -v postgres_data:/data \
            -v "${volumes_backup}":/backup \
            alpine:latest \
            sh -c "rm -rf /data/* && tar -xzf /backup/$(basename ${pg_vol_backup}) -C /data"

        log_info "PostgreSQL data volume restored"
    fi

    # Restart services
    log_info "Restarting services..."
    cd "${COMPOSE_DIR}" && docker compose up -d 2>/dev/null || true

    log_info "Volumes restore completed"
}

# Restore configuration files
restore_configs() {
    local backup_path="$1"
    local config_backup="${backup_path}/configs"

    if [[ ! -d "${config_backup}" ]]; then
        log_warn "Configuration backup directory not found: ${config_backup}"
        return 0
    fi

    log_step "Restoring configuration files..."

    # Restore monitoring configs
    local monitoring_backup
    monitoring_backup=$(find "${config_backup}" -name "monitoring_config_*.tar.gz" | head -1)

    if [[ -n "${monitoring_backup}" ]]; then
        log_info "Restoring monitoring configuration..."
        tar -xzf "${monitoring_backup}" -C "${COMPOSE_DIR}/.." 2>/dev/null || {
            log_warn "Could not restore monitoring configs"
        }
    fi

    # Restore logging configs
    local logging_backup
    logging_backup=$(find "${config_backup}" -name "logging_config_*.tar.gz" | head -1)

    if [[ -n "${logging_backup}" ]]; then
        log_info "Restoring logging configuration..."
        tar -xzf "${logging_backup}" -C "${COMPOSE_DIR}/.." 2>/dev/null || {
            log_warn "Could not restore logging configs"
        }
    fi

    log_info "Configuration restore completed"
}

# Main function
main() {
    # Parse arguments
    BACKUP_NAME=""
    RESTORE_TYPE="all"
    LIST_ONLY=false
    FORCE=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            -b|--backup)
                BACKUP_NAME="$2"
                shift 2
                ;;
            -t|--type)
                RESTORE_TYPE="$2"
                shift 2
                ;;
            -d|--dir)
                BACKUP_DIR="$2"
                shift 2
                ;;
            -l|--list)
                LIST_ONLY=true
                shift
                ;;
            -f|--force)
                FORCE=true
                shift
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

    # List backups only
    if [[ "${LIST_ONLY}" == "true" ]]; then
        list_backups
        exit 0
    fi

    # Validate backup name
    if [[ -z "${BACKUP_NAME}" ]]; then
        log_error "Backup name is required. Use -b option or -l to list available backups."
        usage
    fi

    local backup_path="${BACKUP_DIR}/${BACKUP_NAME}"

    if [[ ! -d "${backup_path}" ]]; then
        log_error "Backup not found: ${backup_path}"
        log_info "Use -l option to list available backups"
        exit 1
    fi

    log_info "=========================================="
    log_info "Starting restore process"
    log_info "Backup: ${BACKUP_NAME}"
    log_info "Restore type: ${RESTORE_TYPE}"
    log_info "=========================================="

    # Confirm restore
    confirm_restore "${BACKUP_NAME}"

    case "${RESTORE_TYPE}" in
        all)
            restore_database "${backup_path}"
            restore_volumes "${backup_path}"
            restore_configs "${backup_path}"
            ;;
        database)
            restore_database "${backup_path}"
            ;;
        volumes)
            restore_volumes "${backup_path}"
            restore_configs "${backup_path}"
            ;;
        *)
            log_error "Invalid restore type: ${RESTORE_TYPE}"
            exit 1
            ;;
    esac

    log_info "=========================================="
    log_info "Restore completed successfully!"
    log_info "=========================================="
}

# Run main
main "$@"

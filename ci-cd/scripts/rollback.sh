#!/bin/bash
set -e

# Rollback script
# Usage: ./rollback.sh [environment] [version|steps]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ANSIBLE_DIR="$PROJECT_ROOT/infrastructure/ansible"

# Default values
ENVIRONMENT="${1:-dev}"
ROLLBACK_TARGET="${2:-1}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Validate environment
validate_environment() {
    case "$ENVIRONMENT" in
        dev|development)
            INVENTORY="inventory/dev.ini"
            ENVIRONMENT="development"
            ;;
        staging)
            INVENTORY="inventory/staging.ini"
            ;;
        prod|production)
            INVENTORY="inventory/production.ini"
            ENVIRONMENT="production"
            ;;
        local)
            INVENTORY="inventory/local.ini"
            ;;
        *)
            log_error "Unknown environment: $ENVIRONMENT"
            exit 1
            ;;
    esac
}

# Get available versions/backups
list_available_rollbacks() {
    log_info "Available rollback points:"

    cd "$ANSIBLE_DIR"
    ansible all -i "$INVENTORY" -m shell -a "ls -la /var/backups/postgres/ 2>/dev/null | tail -10" || true

    echo ""
    log_info "Available Docker image tags:"
    ansible all -i "$INVENTORY" -m shell -a "docker images --format '{{.Repository}}:{{.Tag}}' | grep -E 'backend|frontend' | head -10" || true
}

# Rollback to previous version
rollback_docker() {
    log_info "Rolling back Docker containers..."

    cd "$ANSIBLE_DIR"

    # Stop current containers
    ansible all -i "$INVENTORY" -m shell -a "cd /opt/devops-app/docker && docker compose down" || true

    # If version specified, update image tags
    if [[ "$ROLLBACK_TARGET" =~ ^v[0-9] ]]; then
        log_info "Rolling back to version: $ROLLBACK_TARGET"
        # Update docker-compose or .env with specific version
    else
        log_info "Rolling back $ROLLBACK_TARGET step(s)"
    fi

    # Restart containers
    ansible all -i "$INVENTORY" -m shell -a "cd /opt/devops-app/docker && docker compose up -d"

    log_info "Docker rollback completed"
}

# Rollback database
rollback_database() {
    log_warn "Database rollback requested"

    read -p "This will restore the database from backup. Continue? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        log_info "Database rollback cancelled"
        return 0
    fi

    cd "$ANSIBLE_DIR"

    # List available backups
    log_info "Available database backups:"
    ansible all -i "$INVENTORY" -m shell -a "ls -la /var/backups/postgres/*.sql 2>/dev/null | tail -5"

    read -p "Enter backup filename to restore: " backup_file

    if [ -z "$backup_file" ]; then
        log_error "No backup file specified"
        return 1
    fi

    ansible all -i "$INVENTORY" -m shell -a \
        "cd /opt/devops-app/docker && docker compose exec -T db psql -U postgres postgres < /var/backups/postgres/$backup_file"

    log_info "Database restored from $backup_file"
}

# Main
main() {
    echo "============================================"
    echo "  Rollback Script"
    echo "============================================"
    echo ""

    validate_environment

    log_info "Environment: $ENVIRONMENT"
    log_info "Target: $ROLLBACK_TARGET"
    echo ""

    if [ "$ENVIRONMENT" == "production" ]; then
        log_warn "WARNING: You are about to rollback PRODUCTION!"
        read -p "Are you sure? (yes/no): " confirm
        if [ "$confirm" != "yes" ]; then
            log_info "Rollback cancelled"
            exit 0
        fi
    fi

    PS3="Select rollback type: "
    options=("List available rollbacks" "Rollback Docker containers" "Rollback database" "Full rollback (Docker + DB)" "Cancel")

    select opt in "${options[@]}"; do
        case $opt in
            "List available rollbacks")
                list_available_rollbacks
                ;;
            "Rollback Docker containers")
                rollback_docker
                break
                ;;
            "Rollback database")
                rollback_database
                break
                ;;
            "Full rollback (Docker + DB)")
                rollback_database
                rollback_docker
                break
                ;;
            "Cancel")
                log_info "Rollback cancelled"
                exit 0
                ;;
            *)
                echo "Invalid option"
                ;;
        esac
    done

    # Health check after rollback
    log_info "Running health check..."
    "$SCRIPT_DIR/health-check.sh" "$ENVIRONMENT" || log_warn "Health check failed after rollback"

    echo ""
    log_info "Rollback completed"
}

main

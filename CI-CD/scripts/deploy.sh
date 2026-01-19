#!/bin/bash
set -e

# Deploy script for application
# Usage: ./deploy.sh [dev|staging|production] [--skip-backup] [--force]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ANSIBLE_DIR="$PROJECT_ROOT/infrastructure/ansible"

# Default values
ENVIRONMENT="${1:-dev}"
SKIP_BACKUP=false
FORCE=false

# Parse arguments
shift || true
while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-backup)
            SKIP_BACKUP=true
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
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
            echo "Usage: $0 [dev|staging|production|local]"
            exit 1
            ;;
    esac

    if [ ! -f "$ANSIBLE_DIR/$INVENTORY" ]; then
        log_error "Inventory file not found: $ANSIBLE_DIR/$INVENTORY"
        exit 1
    fi
}

# Pre-deployment checks
pre_deploy_checks() {
    log_step "Running pre-deployment checks..."

    # Check if Ansible is installed
    if ! command -v ansible-playbook &> /dev/null; then
        log_error "Ansible is not installed"
        exit 1
    fi

    # Check SSH connectivity
    log_info "Checking SSH connectivity..."
    cd "$ANSIBLE_DIR"
    ansible all -i "$INVENTORY" -m ping || {
        log_error "Cannot connect to hosts"
        exit 1
    }

    log_info "Pre-deployment checks passed"
}

# Create backup
create_backup() {
    if [ "$SKIP_BACKUP" == "true" ]; then
        log_warn "Skipping backup (--skip-backup flag set)"
        return 0
    fi

    log_step "Creating pre-deployment backup..."

    cd "$ANSIBLE_DIR"
    ansible-playbook \
        -i "$INVENTORY" \
        playbooks/backup.yml \
        -e "environment=$ENVIRONMENT" \
        -e "backup_type=pre-deploy" \
        || log_warn "Backup failed, continuing with deployment..."
}

# Run deployment
run_deploy() {
    log_step "Starting deployment to $ENVIRONMENT..."

    cd "$ANSIBLE_DIR"

    EXTRA_VARS="environment=$ENVIRONMENT"

    if [ "$FORCE" == "true" ]; then
        EXTRA_VARS="$EXTRA_VARS force_recreate=true"
    fi

    ansible-playbook \
        -i "$INVENTORY" \
        playbooks/deploy-app.yml \
        -e "$EXTRA_VARS" \
        -v

    log_info "Deployment completed"
}

# Post-deployment health check
health_check() {
    log_step "Running health checks..."

    "$SCRIPT_DIR/health-check.sh" "$ENVIRONMENT" || {
        log_error "Health check failed!"
        return 1
    }

    log_info "Health checks passed"
}

# Main
main() {
    echo "============================================"
    echo "  Deployment Script"
    echo "============================================"
    echo ""

    validate_environment

    log_info "Environment: $ENVIRONMENT"
    log_info "Inventory: $INVENTORY"
    log_info "Skip Backup: $SKIP_BACKUP"
    log_info "Force: $FORCE"
    echo ""

    if [ "$ENVIRONMENT" == "production" ] && [ "$FORCE" != "true" ]; then
        log_warn "You are about to deploy to PRODUCTION!"
        read -p "Are you sure? (yes/no): " confirm
        if [ "$confirm" != "yes" ]; then
            log_info "Deployment cancelled"
            exit 0
        fi
    fi

    pre_deploy_checks
    create_backup
    run_deploy
    health_check

    echo ""
    echo "============================================"
    log_info "Deployment to $ENVIRONMENT completed successfully!"
    echo "============================================"
}

main

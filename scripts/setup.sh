#!/bin/bash
#
# Setup script for DevOps Project
# Initializes the development environment
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${CYAN}[STEP]${NC} $1"; }

check_command() {
    if ! command -v "$1" &> /dev/null; then
        log_error "$1 is not installed"
        return 1
    fi
    log_info "$1 is installed: $(command -v $1)"
    return 0
}

print_banner() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║     DevOps Project - Setup Script      ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
    echo ""
}

# Check prerequisites
check_prerequisites() {
    log_step "Checking prerequisites..."

    local missing=0

    check_command docker || ((missing++))
    check_command docker compose || check_command docker-compose || ((missing++))
    check_command git || ((missing++))

    if [[ $missing -gt 0 ]]; then
        log_error "Missing $missing required tool(s). Please install them first."
        exit 1
    fi

    # Check Docker daemon
    if ! docker info &> /dev/null; then
        log_error "Docker daemon is not running"
        exit 1
    fi
    log_info "Docker daemon is running"

    echo ""
}

# Create required directories
create_directories() {
    log_step "Creating required directories..."

    local dirs=(
        "${PROJECT_ROOT}/volumes/prometheus-data"
        "${PROJECT_ROOT}/volumes/grafana-data"
        "${PROJECT_ROOT}/volumes/alertmanager-data"
        "${PROJECT_ROOT}/volumes/loki-data"
        "${PROJECT_ROOT}/volumes/logs"
        "${PROJECT_ROOT}/secrets/sops/keys"
    )

    for dir in "${dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            mkdir -p "$dir"
            log_info "Created: $dir"
        else
            log_info "Exists: $dir"
        fi
    done

    echo ""
}

# Setup environment file
setup_env() {
    log_step "Setting up environment..."

    local env_file="${PROJECT_ROOT}/secrets/.env"
    local env_example="${PROJECT_ROOT}/secrets/.env.example"

    if [[ ! -f "$env_file" ]]; then
        if [[ -f "$env_example" ]]; then
            cp "$env_example" "$env_file"
            log_info "Created .env from .env.example"
        else
            cat > "$env_file" << 'EOF'
# Database
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres
POSTGRES_DB=Test
POSTGRES_HOST=db
POSTGRES_PORT=5432

# Grafana
GF_ADMIN_USER=admin
GF_ADMIN_PASSWORD=admin

# PgAdmin
PGADMIN_EMAIL=admin@admin.com
PGADMIN_PASSWORD=admin

# Nginx
NGINX_PORT=80

# Debug
DEBUG=false
EOF
            log_info "Created default .env file"
        fi
        log_warn "Please review and update ${env_file} with your settings"
    else
        log_info ".env file already exists"
    fi

    echo ""
}

# Set permissions
set_permissions() {
    log_step "Setting permissions..."

    # Make scripts executable
    chmod +x "${PROJECT_ROOT}/scripts/"*.sh 2>/dev/null || true
    chmod +x "${PROJECT_ROOT}/backup/"*.sh 2>/dev/null || true
    chmod +x "${PROJECT_ROOT}/ci-cd/scripts/"*.sh 2>/dev/null || true

    log_info "Scripts are now executable"
    echo ""
}

# Build Docker images
build_images() {
    log_step "Building Docker images..."

    cd "${PROJECT_ROOT}/docker"

    if docker compose build; then
        log_info "Docker images built successfully"
    else
        log_error "Failed to build Docker images"
        exit 1
    fi

    echo ""
}

# Print summary
print_summary() {
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║         Setup Complete!                ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Review secrets/.env and update credentials"
    echo "  2. Run './scripts/start-all.sh' to start services"
    echo "  3. Access the application at http://localhost"
    echo ""
    echo "Available commands:"
    echo "  ./scripts/start-all.sh   - Start all services"
    echo "  ./scripts/stop-all.sh    - Stop all services"
    echo "  ./scripts/logs.sh        - View logs"
    echo "  ./scripts/health-check.sh - Check service health"
    echo "  ./scripts/clean.sh       - Clean up environment"
    echo ""
}

# Main
main() {
    print_banner

    cd "$PROJECT_ROOT"

    check_prerequisites
    create_directories
    setup_env
    set_permissions

    # Ask to build images
    read -p "Build Docker images now? (y/n): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        build_images
    fi

    print_summary
}

main "$@"

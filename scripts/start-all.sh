#!/bin/bash
#
# Start all services for DevOps Project
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
DOCKER_DIR="${PROJECT_ROOT}/docker"

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Options:
    -e, --env ENV       Environment: dev, prod (default: dev)
    -b, --build         Build images before starting
    -d, --detach        Run in detached mode (default)
    -f, --foreground    Run in foreground
    -h, --help          Show this help message

Examples:
    $0                  # Start in dev mode (detached)
    $0 -e prod          # Start in production mode
    $0 -b               # Build and start
    $0 -f               # Start in foreground (see logs)
EOF
    exit 0
}

# Parse arguments
ENV="dev"
BUILD=false
DETACH="-d"

while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--env)
            ENV="$2"
            shift 2
            ;;
        -b|--build)
            BUILD=true
            shift
            ;;
        -d|--detach)
            DETACH="-d"
            shift
            ;;
        -f|--foreground)
            DETACH=""
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

# Main
main() {
    echo ""
    log_info "Starting DevOps Project services..."
    log_info "Environment: ${ENV}"
    echo ""

    cd "$DOCKER_DIR"

    # Check if .env exists
    if [[ ! -f "${PROJECT_ROOT}/secrets/.env" ]]; then
        log_warn ".env file not found. Run setup.sh first."
    fi

    # Compose files
    COMPOSE_FILES="-f docker-compose.yml"

    if [[ "$ENV" == "dev" && -f "docker-compose.dev.yml" ]]; then
        COMPOSE_FILES="$COMPOSE_FILES -f docker-compose.dev.yml"
        log_info "Using development overrides"
    elif [[ "$ENV" == "prod" && -f "docker-compose.prod.yml" ]]; then
        COMPOSE_FILES="$COMPOSE_FILES -f docker-compose.prod.yml"
        log_info "Using production overrides"
    fi

    # Build if requested
    if [[ "$BUILD" == true ]]; then
        log_info "Building images..."
        docker compose $COMPOSE_FILES build
        echo ""
    fi

    # Start services
    log_info "Starting containers..."
    docker compose $COMPOSE_FILES up $DETACH

    if [[ -n "$DETACH" ]]; then
        echo ""
        log_info "Services started in background"
        echo ""

        # Wait a moment for services to start
        sleep 3

        # Show status
        docker compose $COMPOSE_FILES ps

        echo ""
        log_info "Access points:"
        echo "  - Application:  http://localhost"
        echo "  - Grafana:      http://localhost/grafana"
        echo "  - Prometheus:   http://localhost:9090"
        echo "  - PgAdmin:      http://localhost/pgadmin"
        echo ""
        log_info "Use './scripts/logs.sh' to view logs"
        log_info "Use './scripts/health-check.sh' to verify services"
    fi
}

main

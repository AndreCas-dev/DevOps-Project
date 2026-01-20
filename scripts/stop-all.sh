#!/bin/bash
#
# Stop all services for DevOps Project
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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
    -v, --volumes       Remove volumes (data will be lost!)
    -r, --remove        Remove containers after stopping
    -a, --all           Stop and remove everything (containers, volumes, networks)
    -h, --help          Show this help message

Examples:
    $0                  # Stop services (keep data)
    $0 -r               # Stop and remove containers
    $0 -v               # Stop and remove volumes (DANGER!)
    $0 -a               # Full cleanup
EOF
    exit 0
}

# Parse arguments
REMOVE_VOLUMES=""
REMOVE_CONTAINERS=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--volumes)
            REMOVE_VOLUMES="-v"
            shift
            ;;
        -r|--remove)
            REMOVE_CONTAINERS="--remove-orphans"
            shift
            ;;
        -a|--all)
            REMOVE_VOLUMES="-v"
            REMOVE_CONTAINERS="--remove-orphans"
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
    log_info "Stopping DevOps Project services..."

    cd "$DOCKER_DIR"

    # Warning for volume removal
    if [[ -n "$REMOVE_VOLUMES" ]]; then
        echo ""
        log_warn "WARNING: This will delete all data volumes!"
        read -p "Are you sure? (yes/no): " confirm
        if [[ "$confirm" != "yes" ]]; then
            log_info "Cancelled"
            exit 0
        fi
    fi

    # Stop services
    docker compose down $REMOVE_VOLUMES $REMOVE_CONTAINERS

    echo ""
    log_info "Services stopped"

    # Show remaining containers if any
    local remaining=$(docker compose ps -q 2>/dev/null | wc -l)
    if [[ $remaining -gt 0 ]]; then
        log_warn "Some containers may still be running"
        docker compose ps
    fi

    echo ""
}

main

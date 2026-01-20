#!/bin/bash
#
# View logs for DevOps Project services
#

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DOCKER_DIR="${PROJECT_ROOT}/docker"

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

usage() {
    cat << EOF
Usage: $0 [OPTIONS] [SERVICE...]

Options:
    -f, --follow        Follow log output (default)
    -n, --tail N        Number of lines to show (default: 100)
    -t, --timestamps    Show timestamps
    --no-follow         Don't follow, just show recent logs
    -h, --help          Show this help message

Services:
    app, frontend, nginx, db, prometheus, grafana, alertmanager,
    loki, fluent-bit, node-exporter, nginx-exporter, postgres-exporter, pgadmin

Examples:
    $0                  # Follow all logs
    $0 app              # Follow app logs only
    $0 -n 50 db         # Show last 50 lines from db
    $0 app nginx        # Follow app and nginx logs
    $0 --no-follow      # Show recent logs and exit
EOF
    exit 0
}

# Parse arguments
FOLLOW="-f"
TAIL="100"
TIMESTAMPS=""
SERVICES=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--follow)
            FOLLOW="-f"
            shift
            ;;
        --no-follow)
            FOLLOW=""
            shift
            ;;
        -n|--tail)
            TAIL="$2"
            shift 2
            ;;
        -t|--timestamps)
            TIMESTAMPS="--timestamps"
            shift
            ;;
        -h|--help)
            usage
            ;;
        -*)
            log_error "Unknown option: $1"
            usage
            ;;
        *)
            SERVICES="$SERVICES $1"
            shift
            ;;
    esac
done

# Main
main() {
    cd "$DOCKER_DIR"

    # Check if any containers are running
    if ! docker compose ps -q 2>/dev/null | grep -q .; then
        log_error "No containers are running"
        echo "Start services with: ./scripts/start-all.sh"
        exit 1
    fi

    if [[ -n "$SERVICES" ]]; then
        log_info "Showing logs for:$SERVICES"
    else
        log_info "Showing logs for all services"
    fi

    echo "Press Ctrl+C to exit"
    echo ""

    docker compose logs --tail="$TAIL" $FOLLOW $TIMESTAMPS $SERVICES
}

main

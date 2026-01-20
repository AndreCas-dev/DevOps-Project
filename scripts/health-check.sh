#!/bin/bash
#
# Health check script for DevOps Project
# Verifies status of all services
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

# Counters
TOTAL=0
HEALTHY=0
UNHEALTHY=0

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

status_ok() { echo -e "  ${GREEN}✓${NC} $1"; ((HEALTHY++)); ((TOTAL++)); }
status_fail() { echo -e "  ${RED}✗${NC} $1"; ((UNHEALTHY++)); ((TOTAL++)); }
status_warn() { echo -e "  ${YELLOW}!${NC} $1"; ((TOTAL++)); }

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Options:
    -v, --verbose       Show detailed output
    -q, --quiet         Only show summary
    -w, --watch         Continuous monitoring (refresh every 5s)
    -h, --help          Show this help message

Examples:
    $0                  # Standard health check
    $0 -v               # Verbose output
    $0 -w               # Watch mode
EOF
    exit 0
}

# Parse arguments
VERBOSE=false
QUIET=false
WATCH=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -q|--quiet)
            QUIET=true
            shift
            ;;
        -w|--watch)
            WATCH=true
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

# Check if container is running
check_container() {
    local name=$1
    local status=$(docker inspect -f '{{.State.Status}}' "$name" 2>/dev/null || echo "not found")

    if [[ "$status" == "running" ]]; then
        local health=$(docker inspect -f '{{.State.Health.Status}}' "$name" 2>/dev/null || echo "none")
        if [[ "$health" == "healthy" || "$health" == "none" ]]; then
            status_ok "$name (running)"
            return 0
        elif [[ "$health" == "unhealthy" ]]; then
            status_fail "$name (unhealthy)"
            return 1
        else
            status_warn "$name (starting)"
            return 0
        fi
    else
        status_fail "$name ($status)"
        return 1
    fi
}

# Check HTTP endpoint
check_http() {
    local name=$1
    local url=$2
    local expected=${3:-200}

    local code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$url" 2>/dev/null || echo "000")

    if [[ "$code" == "$expected" ]]; then
        status_ok "$name (HTTP $code)"
        return 0
    else
        status_fail "$name (HTTP $code, expected $expected)"
        return 1
    fi
}

# Check TCP port
check_port() {
    local name=$1
    local host=$2
    local port=$3

    if nc -z -w 2 "$host" "$port" 2>/dev/null; then
        status_ok "$name (port $port open)"
        return 0
    else
        status_fail "$name (port $port closed)"
        return 1
    fi
}

# Main health check
run_health_check() {
    # Reset counters
    TOTAL=0
    HEALTHY=0
    UNHEALTHY=0

    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║      DevOps Project - Health Check     ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
    echo ""
    echo "Timestamp: $(date)"
    echo ""

    # Docker daemon
    echo -e "${CYAN}Docker:${NC}"
    if docker info &>/dev/null; then
        status_ok "Docker daemon"
    else
        status_fail "Docker daemon"
    fi
    echo ""

    # Core services
    echo -e "${CYAN}Core Services:${NC}"
    check_container "app" || true
    check_container "frontend" || true
    check_container "nginx" || true
    check_container "db" || true
    echo ""

    # Monitoring stack
    echo -e "${CYAN}Monitoring:${NC}"
    check_container "prometheus" || true
    check_container "grafana" || true
    check_container "alertmanager" || true
    check_container "node-exporter" || true
    check_container "nginx-exporter" || true
    check_container "postgres-exporter" || true
    echo ""

    # Logging stack
    echo -e "${CYAN}Logging:${NC}"
    check_container "loki" || true
    check_container "fluent-bit" || true
    echo ""

    # Additional services
    echo -e "${CYAN}Additional:${NC}"
    check_container "pgadmin" || true
    echo ""

    # HTTP endpoints (if verbose)
    if [[ "$VERBOSE" == true ]]; then
        echo -e "${CYAN}HTTP Endpoints:${NC}"
        check_http "Nginx" "http://localhost" || true
        check_http "Prometheus" "http://localhost:9090/-/healthy" || true
        check_http "Grafana" "http://localhost/grafana/api/health" || true
        echo ""
    fi

    # Summary
    echo -e "${CYAN}════════════════════════════════════════${NC}"
    echo ""

    if [[ $UNHEALTHY -eq 0 ]]; then
        echo -e "${GREEN}All services healthy!${NC} ($HEALTHY/$TOTAL)"
    else
        echo -e "${RED}Some services unhealthy!${NC} ($HEALTHY healthy, $UNHEALTHY unhealthy)"
    fi

    echo ""

    return $UNHEALTHY
}

# Watch mode
watch_mode() {
    while true; do
        clear
        run_health_check || true
        echo "Refreshing in 5 seconds... (Ctrl+C to exit)"
        sleep 5
    done
}

# Main
main() {
    cd "$DOCKER_DIR"

    if [[ "$WATCH" == true ]]; then
        watch_mode
    else
        run_health_check
        exit $UNHEALTHY
    fi
}

main

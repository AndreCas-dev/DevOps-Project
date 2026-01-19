#!/bin/bash
set -e

# Health check script
# Usage: ./health-check.sh [environment|host]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Default values
TARGET="${1:-localhost}"
TIMEOUT=5
RETRIES=3
RETRY_DELAY=5

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Determine host based on environment
case "$TARGET" in
    dev|development)
        HOST="${DEV_HOST:-localhost}"
        ;;
    staging)
        HOST="${STAGING_HOST:-localhost}"
        ;;
    prod|production)
        HOST="${PROD_HOST:-localhost}"
        ;;
    local|localhost)
        HOST="localhost"
        ;;
    *)
        # Assume it's a hostname/IP
        HOST="$TARGET"
        ;;
esac

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_fail() {
    echo -e "${RED}[✗]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[!]${NC} $1"
}

# Check endpoint with retries
check_endpoint() {
    local name="$1"
    local url="$2"
    local expected_code="${3:-200}"

    for i in $(seq 1 $RETRIES); do
        response=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout $TIMEOUT "$url" 2>/dev/null || echo "000")

        if [ "$response" == "$expected_code" ]; then
            log_success "$name: OK (HTTP $response)"
            return 0
        fi

        if [ $i -lt $RETRIES ]; then
            sleep $RETRY_DELAY
        fi
    done

    log_fail "$name: FAILED (HTTP $response, expected $expected_code)"
    return 1
}

# Check service is responding
check_service() {
    local name="$1"
    local port="$2"

    if nc -z -w $TIMEOUT "$HOST" "$port" 2>/dev/null; then
        log_success "$name (port $port): Reachable"
        return 0
    else
        log_fail "$name (port $port): Unreachable"
        return 1
    fi
}

# Main health checks
main() {
    echo "============================================"
    echo "  Health Check - $HOST"
    echo "============================================"
    echo ""

    local failed=0

    # Application endpoints
    echo "Application Endpoints:"
    echo "----------------------"
    check_endpoint "Main page" "http://$HOST/" || ((failed++))
    check_endpoint "API health" "http://$HOST/health" || ((failed++))
    check_endpoint "API docs" "http://$HOST/docs" || ((failed++))
    echo ""

    # Monitoring endpoints
    echo "Monitoring Endpoints:"
    echo "---------------------"
    check_endpoint "Prometheus" "http://$HOST/prometheus/-/healthy" || ((failed++))
    check_endpoint "Grafana" "http://$HOST/grafana/api/health" || ((failed++))
    check_endpoint "Alertmanager" "http://$HOST/alertmanager/-/healthy" || ((failed++))
    echo ""

    # Logging endpoints
    echo "Logging Endpoints:"
    echo "------------------"
    check_endpoint "Loki" "http://$HOST/loki/ready" || log_warn "Loki not responding (may be normal)"
    echo ""

    # Summary
    echo "============================================"
    if [ $failed -eq 0 ]; then
        log_success "All health checks passed!"
        exit 0
    else
        log_fail "$failed health check(s) failed"
        exit 1
    fi
}

main

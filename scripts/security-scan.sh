#!/bin/bash
#
# Security scan script for DevOps Project
# Runs all security checks locally
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

# Counters
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
SKIPPED_CHECKS=0

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${CYAN}[SCAN]${NC} $1"; }

check_pass() { echo -e "  ${GREEN}✓${NC} $1"; ((PASSED_CHECKS++)); ((TOTAL_CHECKS++)); }
check_fail() { echo -e "  ${RED}✗${NC} $1"; ((FAILED_CHECKS++)); ((TOTAL_CHECKS++)); }
check_skip() { echo -e "  ${YELLOW}○${NC} $1 (skipped)"; ((SKIPPED_CHECKS++)); ((TOTAL_CHECKS++)); }

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Options:
    -a, --all           Run all scans (default)
    -s, --secrets       Run secrets scan (Gitleaks)
    -v, --vuln          Run vulnerability scan (Trivy)
    -d, --deps          Run dependency audit (npm)
    -i, --images        Scan Docker images
    --install           Install missing tools
    -h, --help          Show this help message

Examples:
    $0                  # Run all scans
    $0 -s               # Only secrets scan
    $0 -v -d            # Vulnerability and dependency scans
    $0 --install        # Install tools then scan
EOF
    exit 0
}

# Check if command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Install tools
install_tools() {
    log_step "Installing security tools..."

    # Detect OS
    if [[ "$OSTYPE" == "darwin"* ]]; then
        PKG_MANAGER="brew install"
    elif command_exists apt; then
        PKG_MANAGER="sudo apt install -y"
    elif command_exists dnf; then
        PKG_MANAGER="sudo dnf install -y"
    else
        log_error "Unsupported package manager"
        return 1
    fi

    # Install Gitleaks
    if ! command_exists gitleaks; then
        log_info "Installing Gitleaks..."
        if [[ "$OSTYPE" == "darwin"* ]]; then
            brew install gitleaks
        else
            # Download from GitHub releases
            GITLEAKS_VERSION="8.18.1"
            curl -sSL "https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_linux_x64.tar.gz" | sudo tar -xz -C /usr/local/bin gitleaks
        fi
    fi

    # Install Trivy
    if ! command_exists trivy; then
        log_info "Installing Trivy..."
        if [[ "$OSTYPE" == "darwin"* ]]; then
            brew install trivy
        else
            sudo apt-get install -y wget apt-transport-https gnupg lsb-release
            wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
            echo "deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | sudo tee /etc/apt/sources.list.d/trivy.list
            sudo apt-get update
            sudo apt-get install -y trivy
        fi
    fi

    log_info "Tools installed successfully"
}

# Secrets scan with Gitleaks
scan_secrets() {
    log_step "Scanning for secrets (Gitleaks)..."

    if ! command_exists gitleaks; then
        check_skip "Gitleaks not installed (use --install)"
        return
    fi

    cd "$PROJECT_ROOT"

    local config_file="ci-cd/security/gitleaks.toml"
    local gitleaks_args="detect --source . --no-git"

    if [[ -f "$config_file" ]]; then
        gitleaks_args="$gitleaks_args --config $config_file"
    fi

    if gitleaks $gitleaks_args --exit-code 0 > /tmp/gitleaks-report.txt 2>&1; then
        check_pass "No secrets detected"
    else
        local findings=$(grep -c "Finding:" /tmp/gitleaks-report.txt 2>/dev/null || echo "0")
        if [[ "$findings" -gt 0 ]]; then
            check_fail "Found $findings potential secret(s)"
            echo ""
            cat /tmp/gitleaks-report.txt
            echo ""
        else
            check_pass "No secrets detected"
        fi
    fi
}

# Vulnerability scan with Trivy
scan_vulnerabilities() {
    log_step "Scanning for vulnerabilities (Trivy)..."

    if ! command_exists trivy; then
        check_skip "Trivy not installed (use --install)"
        return
    fi

    cd "$PROJECT_ROOT"

    # Scan filesystem
    echo ""
    log_info "Scanning repository..."
    if trivy fs . --severity HIGH,CRITICAL --exit-code 0 --quiet > /tmp/trivy-fs.txt 2>&1; then
        local vulns=$(grep -c "Total:" /tmp/trivy-fs.txt 2>/dev/null || echo "0")
        if [[ "$vulns" -eq 0 ]] || ! grep -q "CRITICAL\|HIGH" /tmp/trivy-fs.txt; then
            check_pass "No HIGH/CRITICAL vulnerabilities in code"
        else
            check_fail "Vulnerabilities found in code"
            trivy fs . --severity HIGH,CRITICAL 2>/dev/null | head -50
        fi
    else
        check_pass "No HIGH/CRITICAL vulnerabilities in code"
    fi

    # Scan config files
    log_info "Scanning configurations..."
    if trivy config . --severity HIGH,CRITICAL --exit-code 0 --quiet > /tmp/trivy-config.txt 2>&1; then
        if grep -q "CRITICAL\|HIGH" /tmp/trivy-config.txt; then
            check_fail "Misconfigurations found"
            trivy config . --severity HIGH,CRITICAL 2>/dev/null | head -30
        else
            check_pass "No HIGH/CRITICAL misconfigurations"
        fi
    else
        check_pass "No HIGH/CRITICAL misconfigurations"
    fi
}

# Scan Docker images
scan_images() {
    log_step "Scanning Docker images (Trivy)..."

    if ! command_exists trivy; then
        check_skip "Trivy not installed (use --install)"
        return
    fi

    if ! command_exists docker; then
        check_skip "Docker not installed"
        return
    fi

    cd "$PROJECT_ROOT/docker"

    # Get list of project images
    local images=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep -E "backend|frontend|app" | head -5)

    if [[ -z "$images" ]]; then
        log_info "No project images found. Building for scan..."

        # Build images if they don't exist
        if [[ -f "docker-compose.yml" ]]; then
            docker compose build --quiet 2>/dev/null || true
            images=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep -E "backend|frontend|app" | head -5)
        fi
    fi

    if [[ -z "$images" ]]; then
        check_skip "No Docker images to scan"
        return
    fi

    for image in $images; do
        log_info "Scanning image: $image"
        if trivy image "$image" --severity HIGH,CRITICAL --exit-code 0 --quiet > /tmp/trivy-image.txt 2>&1; then
            if grep -q "CRITICAL\|HIGH" /tmp/trivy-image.txt; then
                check_fail "$image has vulnerabilities"
            else
                check_pass "$image is clean"
            fi
        else
            check_pass "$image is clean"
        fi
    done
}

# Dependency audit
scan_dependencies() {
    log_step "Auditing dependencies (npm)..."

    cd "$PROJECT_ROOT"

    # Backend
    if [[ -f "docker/backend/package.json" ]]; then
        log_info "Checking backend dependencies..."
        cd "$PROJECT_ROOT/docker/backend"

        if [[ ! -d "node_modules" ]]; then
            npm install --silent 2>/dev/null || true
        fi

        local audit_result=$(npm audit --audit-level=high 2>/dev/null || true)
        local high_vulns=$(echo "$audit_result" | grep -c "high" 2>/dev/null || echo "0")
        local critical_vulns=$(echo "$audit_result" | grep -c "critical" 2>/dev/null || echo "0")

        if [[ "$high_vulns" -eq 0 ]] && [[ "$critical_vulns" -eq 0 ]]; then
            check_pass "Backend: No high/critical vulnerabilities"
        else
            check_fail "Backend: $high_vulns high, $critical_vulns critical"
        fi
    fi

    # Frontend
    if [[ -f "$PROJECT_ROOT/docker/frontend/package.json" ]]; then
        log_info "Checking frontend dependencies..."
        cd "$PROJECT_ROOT/docker/frontend"

        if [[ ! -d "node_modules" ]]; then
            npm install --silent 2>/dev/null || true
        fi

        local audit_result=$(npm audit --audit-level=high 2>/dev/null || true)
        local high_vulns=$(echo "$audit_result" | grep -c "high" 2>/dev/null || echo "0")
        local critical_vulns=$(echo "$audit_result" | grep -c "critical" 2>/dev/null || echo "0")

        if [[ "$high_vulns" -eq 0 ]] && [[ "$critical_vulns" -eq 0 ]]; then
            check_pass "Frontend: No high/critical vulnerabilities"
        else
            check_fail "Frontend: $high_vulns high, $critical_vulns critical"
        fi
    fi

    # E2E tests
    if [[ -f "$PROJECT_ROOT/tests/e2e/package.json" ]]; then
        log_info "Checking E2E test dependencies..."
        cd "$PROJECT_ROOT/tests/e2e"

        if [[ ! -d "node_modules" ]]; then
            npm install --silent 2>/dev/null || true
        fi

        local audit_result=$(npm audit --audit-level=high 2>/dev/null || true)
        local high_vulns=$(echo "$audit_result" | grep -c "high" 2>/dev/null || echo "0")
        local critical_vulns=$(echo "$audit_result" | grep -c "critical" 2>/dev/null || echo "0")

        if [[ "$high_vulns" -eq 0 ]] && [[ "$critical_vulns" -eq 0 ]]; then
            check_pass "E2E Tests: No high/critical vulnerabilities"
        else
            check_fail "E2E Tests: $high_vulns high, $critical_vulns critical"
        fi
    fi
}

# Print summary
print_summary() {
    echo ""
    echo -e "${CYAN}════════════════════════════════════════${NC}"
    echo -e "${CYAN}           Security Scan Summary        ${NC}"
    echo -e "${CYAN}════════════════════════════════════════${NC}"
    echo ""
    echo -e "  Total checks:  $TOTAL_CHECKS"
    echo -e "  ${GREEN}Passed:${NC}        $PASSED_CHECKS"
    echo -e "  ${RED}Failed:${NC}        $FAILED_CHECKS"
    echo -e "  ${YELLOW}Skipped:${NC}       $SKIPPED_CHECKS"
    echo ""

    if [[ $FAILED_CHECKS -eq 0 ]]; then
        echo -e "${GREEN}All security checks passed!${NC}"
        return 0
    else
        echo -e "${RED}Some security checks failed. Review the output above.${NC}"
        return 1
    fi
}

# Main
main() {
    local run_secrets=false
    local run_vuln=false
    local run_deps=false
    local run_images=false
    local do_install=false
    local run_all=true

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -a|--all)
                run_all=true
                shift
                ;;
            -s|--secrets)
                run_secrets=true
                run_all=false
                shift
                ;;
            -v|--vuln)
                run_vuln=true
                run_all=false
                shift
                ;;
            -d|--deps)
                run_deps=true
                run_all=false
                shift
                ;;
            -i|--images)
                run_images=true
                run_all=false
                shift
                ;;
            --install)
                do_install=true
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

    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║     DevOps Project Security Scan       ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
    echo ""
    echo "Timestamp: $(date)"
    echo ""

    # Install tools if requested
    if [[ "$do_install" == true ]]; then
        install_tools
        echo ""
    fi

    # Run scans
    if [[ "$run_all" == true ]]; then
        scan_secrets
        echo ""
        scan_vulnerabilities
        echo ""
        scan_dependencies
        echo ""
        scan_images
    else
        [[ "$run_secrets" == true ]] && { scan_secrets; echo ""; }
        [[ "$run_vuln" == true ]] && { scan_vulnerabilities; echo ""; }
        [[ "$run_deps" == true ]] && { scan_dependencies; echo ""; }
        [[ "$run_images" == true ]] && { scan_images; echo ""; }
    fi

    print_summary
}

main "$@"

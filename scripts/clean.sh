#!/bin/bash
#
# Clean up script for DevOps Project
# Removes containers, images, volumes, and other artifacts
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
log_step() { echo -e "${CYAN}[STEP]${NC} $1"; }

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Options:
    -c, --containers    Remove project containers
    -i, --images        Remove project images
    -v, --volumes       Remove project volumes (DATA LOSS!)
    -n, --networks      Remove project networks
    -a, --all           Remove everything (DANGER!)
    -p, --prune         Docker system prune (removes unused resources)
    --dry-run           Show what would be removed
    -h, --help          Show this help message

Examples:
    $0 -c               # Remove containers only
    $0 -c -i            # Remove containers and images
    $0 -a               # Full cleanup (DANGER!)
    $0 -p               # Prune unused Docker resources
    $0 --dry-run -a     # Preview full cleanup
EOF
    exit 0
}

# Parse arguments
CLEAN_CONTAINERS=false
CLEAN_IMAGES=false
CLEAN_VOLUMES=false
CLEAN_NETWORKS=false
PRUNE=false
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--containers)
            CLEAN_CONTAINERS=true
            shift
            ;;
        -i|--images)
            CLEAN_IMAGES=true
            shift
            ;;
        -v|--volumes)
            CLEAN_VOLUMES=true
            shift
            ;;
        -n|--networks)
            CLEAN_NETWORKS=true
            shift
            ;;
        -a|--all)
            CLEAN_CONTAINERS=true
            CLEAN_IMAGES=true
            CLEAN_VOLUMES=true
            CLEAN_NETWORKS=true
            shift
            ;;
        -p|--prune)
            PRUNE=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
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

# Check if any option selected
if [[ "$CLEAN_CONTAINERS" == false && "$CLEAN_IMAGES" == false && \
      "$CLEAN_VOLUMES" == false && "$CLEAN_NETWORKS" == false && \
      "$PRUNE" == false ]]; then
    log_error "No cleanup option selected"
    usage
fi

# Confirm dangerous operations
confirm_action() {
    if [[ "$DRY_RUN" == true ]]; then
        return 0
    fi

    echo ""
    log_warn "WARNING: This operation cannot be undone!"

    if [[ "$CLEAN_VOLUMES" == true ]]; then
        log_warn "ALL DATA IN VOLUMES WILL BE LOST!"
    fi

    echo ""
    read -p "Type 'yes' to confirm: " confirm
    if [[ "$confirm" != "yes" ]]; then
        log_info "Cancelled"
        exit 0
    fi
}

# Clean containers
clean_containers() {
    log_step "Removing containers..."

    cd "$DOCKER_DIR"

    if [[ "$DRY_RUN" == true ]]; then
        echo "Would remove:"
        docker compose ps -a --format "table {{.Name}}\t{{.Status}}"
    else
        docker compose down --remove-orphans 2>/dev/null || true
        log_info "Containers removed"
    fi
}

# Clean images
clean_images() {
    log_step "Removing project images..."

    local images=$(docker images --filter "reference=docker-*" -q 2>/dev/null || true)
    local compose_images=$(docker compose -f "$DOCKER_DIR/docker-compose.yml" config --images 2>/dev/null || true)

    if [[ "$DRY_RUN" == true ]]; then
        echo "Would remove images:"
        echo "$compose_images"
    else
        if [[ -n "$compose_images" ]]; then
            echo "$compose_images" | xargs -r docker rmi -f 2>/dev/null || true
        fi
        log_info "Images removed"
    fi
}

# Clean volumes
clean_volumes() {
    log_step "Removing volumes..."

    cd "$DOCKER_DIR"

    if [[ "$DRY_RUN" == true ]]; then
        echo "Would remove volumes:"
        docker compose config --volumes 2>/dev/null || true
        echo ""
        echo "Would clean directories:"
        echo "  - ${PROJECT_ROOT}/volumes/prometheus-data/*"
        echo "  - ${PROJECT_ROOT}/volumes/grafana-data/*"
        echo "  - ${PROJECT_ROOT}/volumes/alertmanager-data/*"
        echo "  - ${PROJECT_ROOT}/volumes/loki-data/*"
        echo "  - ${PROJECT_ROOT}/volumes/logs/*"
    else
        # Remove Docker volumes
        docker compose down -v 2>/dev/null || true

        # Clean local volume directories
        rm -rf "${PROJECT_ROOT}/volumes/prometheus-data/"* 2>/dev/null || true
        rm -rf "${PROJECT_ROOT}/volumes/grafana-data/"* 2>/dev/null || true
        rm -rf "${PROJECT_ROOT}/volumes/alertmanager-data/"* 2>/dev/null || true
        rm -rf "${PROJECT_ROOT}/volumes/loki-data/"* 2>/dev/null || true
        rm -rf "${PROJECT_ROOT}/volumes/logs/"* 2>/dev/null || true

        log_info "Volumes removed"
    fi
}

# Clean networks
clean_networks() {
    log_step "Removing networks..."

    if [[ "$DRY_RUN" == true ]]; then
        echo "Would remove networks:"
        docker network ls --filter "name=devops" --format "{{.Name}}"
    else
        docker network ls --filter "name=devops" -q | xargs -r docker network rm 2>/dev/null || true
        log_info "Networks removed"
    fi
}

# Docker prune
docker_prune() {
    log_step "Pruning Docker system..."

    if [[ "$DRY_RUN" == true ]]; then
        echo "Would run: docker system prune -f"
        docker system df
    else
        docker system prune -f
        log_info "Docker system pruned"
    fi
}

# Main
main() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║     DevOps Project - Cleanup Script    ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
    echo ""

    if [[ "$DRY_RUN" == true ]]; then
        log_info "DRY RUN MODE - No changes will be made"
        echo ""
    fi

    # Confirm if removing volumes
    if [[ "$CLEAN_VOLUMES" == true && "$DRY_RUN" == false ]]; then
        confirm_action
    fi

    # Execute cleanup
    [[ "$CLEAN_CONTAINERS" == true ]] && clean_containers
    [[ "$CLEAN_IMAGES" == true ]] && clean_images
    [[ "$CLEAN_VOLUMES" == true ]] && clean_volumes
    [[ "$CLEAN_NETWORKS" == true ]] && clean_networks
    [[ "$PRUNE" == true ]] && docker_prune

    echo ""
    if [[ "$DRY_RUN" == true ]]; then
        log_info "Dry run complete. No changes made."
    else
        log_info "Cleanup complete!"
    fi
    echo ""
}

main

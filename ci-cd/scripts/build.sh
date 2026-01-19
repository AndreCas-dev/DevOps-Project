#!/bin/bash
set -e

# Build script for Docker images
# Usage: ./build.sh [backend|frontend|all] [tag]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DOCKER_DIR="$PROJECT_ROOT/docker"

# Default values
TARGET="${1:-all}"
TAG="${2:-latest}"
REGISTRY="${REGISTRY:-ghcr.io}"
IMAGE_PREFIX="${IMAGE_PREFIX:-}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

build_backend() {
    log_info "Building backend image..."

    if [ ! -f "$DOCKER_DIR/backend/Dockerfile" ]; then
        log_error "Backend Dockerfile not found at $DOCKER_DIR/backend/Dockerfile"
        return 1
    fi

    local image_name="${IMAGE_PREFIX}backend:${TAG}"

    docker build \
        -t "$image_name" \
        -f "$DOCKER_DIR/backend/Dockerfile" \
        "$DOCKER_DIR/backend"

    log_info "Backend image built: $image_name"
}

build_frontend() {
    log_info "Building frontend image..."

    if [ ! -f "$DOCKER_DIR/frontend/Dockerfile" ]; then
        log_error "Frontend Dockerfile not found at $DOCKER_DIR/frontend/Dockerfile"
        return 1
    fi

    local image_name="${IMAGE_PREFIX}frontend:${TAG}"

    docker build \
        -t "$image_name" \
        -f "$DOCKER_DIR/frontend/Dockerfile" \
        "$DOCKER_DIR/frontend"

    log_info "Frontend image built: $image_name"
}

push_images() {
    if [ -z "$REGISTRY" ]; then
        log_warn "No registry specified, skipping push"
        return 0
    fi

    log_info "Pushing images to registry..."

    if [ "$TARGET" == "all" ] || [ "$TARGET" == "backend" ]; then
        docker tag "${IMAGE_PREFIX}backend:${TAG}" "$REGISTRY/${IMAGE_PREFIX}backend:${TAG}"
        docker push "$REGISTRY/${IMAGE_PREFIX}backend:${TAG}"
    fi

    if [ "$TARGET" == "all" ] || [ "$TARGET" == "frontend" ]; then
        docker tag "${IMAGE_PREFIX}frontend:${TAG}" "$REGISTRY/${IMAGE_PREFIX}frontend:${TAG}"
        docker push "$REGISTRY/${IMAGE_PREFIX}frontend:${TAG}"
    fi

    log_info "Images pushed successfully"
}

# Main
log_info "Starting build process..."
log_info "Target: $TARGET"
log_info "Tag: $TAG"

case "$TARGET" in
    backend)
        build_backend
        ;;
    frontend)
        build_frontend
        ;;
    all)
        build_backend
        build_frontend
        ;;
    *)
        log_error "Unknown target: $TARGET"
        echo "Usage: $0 [backend|frontend|all] [tag]"
        exit 1
        ;;
esac

# Push if PUSH_IMAGES is set
if [ "${PUSH_IMAGES:-false}" == "true" ]; then
    push_images
fi

log_info "Build completed successfully!"

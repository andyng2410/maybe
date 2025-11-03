#!/bin/bash
# Script tự động rebuild và deploy custom Maybe image

set -e

# ==================== CONFIGURATION ====================
SOURCE_DIR="${SOURCE_DIR:-$HOME/maybe}"
DEPLOY_DIR="${DEPLOY_DIR:-$HOME/maybe-app}"
IMAGE_NAME="${IMAGE_NAME:-maybe-custom}"
VERSION="${VERSION:-latest}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ==================== FUNCTIONS ====================

log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

check_directories() {
    log_info "Checking directories..."

    if [ ! -d "$SOURCE_DIR" ]; then
        log_error "Source directory not found: $SOURCE_DIR"
        exit 1
    fi

    if [ ! -d "$DEPLOY_DIR" ]; then
        log_error "Deploy directory not found: $DEPLOY_DIR"
        exit 1
    fi

    log_success "Directories OK"
}

backup_current_image() {
    log_info "Backing up current image..."

    if docker image inspect "$IMAGE_NAME:$VERSION" &> /dev/null; then
        BACKUP_TAG="backup-$(date +%Y%m%d-%H%M%S)"
        docker tag "$IMAGE_NAME:$VERSION" "$IMAGE_NAME:$BACKUP_TAG"
        log_success "Current image backed up as: $IMAGE_NAME:$BACKUP_TAG"
    else
        log_warning "No existing image to backup"
    fi
}

build_image() {
    log_info "Building Docker image..."

    cd "$SOURCE_DIR"

    # Build with timestamp tag
    TIMESTAMP_TAG="build-$(date +%Y%m%d-%H%M%S)"

    docker build \
        --build-arg BUILD_COMMIT_SHA="$(git rev-parse HEAD 2>/dev/null || echo 'unknown')" \
        -t "$IMAGE_NAME:$TIMESTAMP_TAG" \
        -t "$IMAGE_NAME:$VERSION" \
        .

    log_success "Image built: $IMAGE_NAME:$VERSION"
    log_success "Timestamp tag: $IMAGE_NAME:$TIMESTAMP_TAG"
}

restart_services() {
    log_info "Restarting services..."

    cd "$DEPLOY_DIR"

    # Stop services
    docker compose down

    # Start with new image
    docker compose up -d

    log_success "Services restarted"
}

check_health() {
    log_info "Checking service health..."

    cd "$DEPLOY_DIR"

    # Wait a bit for services to start
    sleep 5

    # Check status
    docker compose ps

    echo ""
    log_info "Recent logs (last 20 lines):"
    docker compose logs --tail=20 web

    echo ""
    log_success "Health check complete"
}

show_summary() {
    echo ""
    echo "=========================================="
    log_success "Rebuild completed successfully!"
    echo "=========================================="
    echo ""
    echo "📦 Image: $IMAGE_NAME:$VERSION"
    echo "📁 Source: $SOURCE_DIR"
    echo "🚀 Deploy: $DEPLOY_DIR"
    echo "🌐 URL: http://localhost:3000"
    echo ""
    echo "Useful commands:"
    echo "  docker compose logs -f          # View logs"
    echo "  docker compose ps               # Check status"
    echo "  docker compose restart web      # Restart web service"
    echo ""
}

# ==================== MAIN ====================

main() {
    echo ""
    echo "=========================================="
    echo "🔨 Maybe Custom Image Rebuild"
    echo "=========================================="
    echo ""

    check_directories
    backup_current_image
    build_image
    restart_services
    check_health
    show_summary
}

# Run main function
main

exit 0

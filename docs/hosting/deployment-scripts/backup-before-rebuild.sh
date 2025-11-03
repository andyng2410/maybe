#!/bin/bash
# Script backup database và image trước khi rebuild

set -e

# ==================== CONFIGURATION ====================
DEPLOY_DIR="${DEPLOY_DIR:-$HOME/maybe-app}"
BACKUP_DIR="${BACKUP_DIR:-$HOME/maybe-backups}"
IMAGE_NAME="${IMAGE_NAME:-maybe-custom}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

setup_backup_dir() {
    log_info "Setting up backup directory..."

    mkdir -p "$BACKUP_DIR"

    log_success "Backup directory: $BACKUP_DIR"
}

backup_database() {
    log_info "Backing up database..."

    cd "$DEPLOY_DIR"

    # Check if db service is running
    if ! docker compose ps db | grep -q "Up"; then
        log_warning "Database service is not running, skipping database backup"
        return
    fi

    TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    BACKUP_FILE="$BACKUP_DIR/database-$TIMESTAMP.sql.gz"

    # Backup database
    docker compose exec -T db pg_dump \
        -U maybe_user \
        -d maybe_production \
        --no-owner \
        --no-acl | gzip > "$BACKUP_FILE"

    BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)

    log_success "Database backed up: $BACKUP_FILE ($BACKUP_SIZE)"
}

backup_docker_image() {
    log_info "Backing up Docker image..."

    if ! docker image inspect "$IMAGE_NAME:latest" &> /dev/null; then
        log_warning "No image to backup: $IMAGE_NAME:latest"
        return
    fi

    TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    BACKUP_TAG="backup-$TIMESTAMP"

    # Tag current image
    docker tag "$IMAGE_NAME:latest" "$IMAGE_NAME:$BACKUP_TAG"

    log_success "Image backed up as: $IMAGE_NAME:$BACKUP_TAG"

    # Optionally save to file
    read -p "Do you want to save image to tar file? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        BACKUP_FILE="$BACKUP_DIR/image-$TIMESTAMP.tar.gz"
        log_info "Saving image to: $BACKUP_FILE"
        docker save "$IMAGE_NAME:$BACKUP_TAG" | gzip > "$BACKUP_FILE"

        BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
        log_success "Image saved: $BACKUP_FILE ($BACKUP_SIZE)"
    fi
}

backup_volumes() {
    log_info "Backing up Docker volumes..."

    cd "$DEPLOY_DIR"

    TIMESTAMP=$(date +%Y%m%d-%H%M%S)

    # Backup app storage
    if docker volume inspect maybe-app_app-storage &> /dev/null; then
        BACKUP_FILE="$BACKUP_DIR/app-storage-$TIMESTAMP.tar.gz"
        docker run --rm \
            -v maybe-app_app-storage:/data \
            -v "$BACKUP_DIR":/backup \
            alpine tar czf "/backup/app-storage-$TIMESTAMP.tar.gz" -C /data .

        BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
        log_success "App storage backed up: $BACKUP_FILE ($BACKUP_SIZE)"
    fi
}

backup_env_file() {
    log_info "Backing up .env file..."

    cd "$DEPLOY_DIR"

    if [ -f .env ]; then
        TIMESTAMP=$(date +%Y%m%d-%H%M%S)
        BACKUP_FILE="$BACKUP_DIR/env-$TIMESTAMP.txt"

        cp .env "$BACKUP_FILE"

        log_success ".env backed up: $BACKUP_FILE"
        log_warning "Keep this file secure - it contains secrets!"
    else
        log_warning "No .env file found"
    fi
}

cleanup_old_backups() {
    log_info "Cleaning up old backups (older than 30 days)..."

    DELETED=$(find "$BACKUP_DIR" -type f -mtime +30 | wc -l)

    if [ "$DELETED" -gt 0 ]; then
        find "$BACKUP_DIR" -type f -mtime +30 -delete
        log_success "Deleted $DELETED old backup files"
    else
        log_info "No old backups to clean up"
    fi
}

list_backups() {
    log_info "Recent backups in $BACKUP_DIR:"
    echo ""

    ls -lh "$BACKUP_DIR" | tail -n 10

    echo ""
    log_info "Total backup size: $(du -sh "$BACKUP_DIR" | cut -f1)"
}

show_restore_info() {
    echo ""
    echo "=============================================="
    log_info "To restore from backup:"
    echo "=============================================="
    echo ""
    echo "Database:"
    echo "  gunzip < $BACKUP_DIR/database-TIMESTAMP.sql.gz | \\"
    echo "    docker compose exec -T db psql -U maybe_user -d maybe_production"
    echo ""
    echo "Docker Image:"
    echo "  docker load < $BACKUP_DIR/image-TIMESTAMP.tar.gz"
    echo "  # OR"
    echo "  docker tag $IMAGE_NAME:backup-TIMESTAMP $IMAGE_NAME:latest"
    echo ""
    echo "App Storage:"
    echo "  docker run --rm \\"
    echo "    -v maybe-app_app-storage:/data \\"
    echo "    -v $BACKUP_DIR:/backup \\"
    echo "    alpine sh -c 'rm -rf /data/* && tar xzf /backup/app-storage-TIMESTAMP.tar.gz -C /data'"
    echo ""
}

show_summary() {
    echo ""
    echo "=============================================="
    log_success "Backup completed successfully! 💾"
    echo "=============================================="
    echo ""
    echo "📁 Backup location: $BACKUP_DIR"
    echo ""
    list_backups
    show_restore_info
}

# ==================== MAIN ====================

main() {
    echo ""
    echo "=============================================="
    echo "💾 Maybe Backup Before Rebuild"
    echo "=============================================="
    echo ""

    setup_backup_dir
    backup_database
    backup_docker_image
    backup_volumes
    backup_env_file
    cleanup_old_backups
    show_summary
}

# Run main function
main

exit 0

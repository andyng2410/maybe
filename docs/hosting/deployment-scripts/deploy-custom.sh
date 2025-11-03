#!/bin/bash
# Script setup và deploy Maybe với custom image

set -e

# ==================== CONFIGURATION ====================
SOURCE_DIR="${SOURCE_DIR:-$HOME/maybe}"
DEPLOY_DIR="${DEPLOY_DIR:-$HOME/maybe-deploy}"
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

check_docker() {
    log_info "Checking Docker installation..."

    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed!"
        echo "Please install Docker first:"
        echo "  curl -fsSL https://get.docker.com -o get-docker.sh"
        echo "  sudo sh get-docker.sh"
        exit 1
    fi

    if ! docker info &> /dev/null; then
        log_error "Docker daemon is not running!"
        exit 1
    fi

    log_success "Docker OK"
}

setup_source() {
    log_info "Setting up source code..."

    if [ ! -d "$SOURCE_DIR" ]; then
        log_info "Cloning Maybe repository..."
        git clone https://github.com/maybe-finance/maybe.git "$SOURCE_DIR"
        log_success "Repository cloned to: $SOURCE_DIR"
    else
        log_info "Source directory exists: $SOURCE_DIR"

        # Ask if user wants to update
        read -p "Do you want to pull latest changes? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            cd "$SOURCE_DIR"
            git pull origin main
            log_success "Code updated"
        fi
    fi
}

build_image() {
    log_info "Building Docker image..."

    cd "$SOURCE_DIR"

    docker build \
        --build-arg BUILD_COMMIT_SHA="$(git rev-parse HEAD 2>/dev/null || echo 'unknown')" \
        -t "$IMAGE_NAME:latest" \
        -t "$IMAGE_NAME:$(date +%Y%m%d-%H%M%S)" \
        .

    log_success "Image built: $IMAGE_NAME:latest"
}

setup_deploy_dir() {
    log_info "Setting up deployment directory..."

    mkdir -p "$DEPLOY_DIR"
    cd "$DEPLOY_DIR"

    log_success "Deploy directory: $DEPLOY_DIR"
}

create_compose_file() {
    log_info "Creating docker-compose.yml..."

    cd "$DEPLOY_DIR"

    cat > compose.yml << 'EOF'
services:
  web:
    image: maybe-custom:latest
    volumes:
      - app-storage:/rails/storage
    ports:
      - 3000:3000
    restart: unless-stopped
    environment:
      SECRET_KEY_BASE: ${SECRET_KEY_BASE}
      POSTGRES_USER: ${POSTGRES_USER:-maybe_user}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: ${POSTGRES_DB:-maybe_production}
      SELF_HOSTED: "true"
      RAILS_FORCE_SSL: "false"
      RAILS_ASSUME_SSL: "false"
      DB_HOST: db
      DB_PORT: 5432
      REDIS_URL: redis://redis:6379/1
      OPENAI_ACCESS_TOKEN: ${OPENAI_ACCESS_TOKEN}
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_healthy
    networks:
      - maybe_net

  worker:
    image: maybe-custom:latest
    command: bundle exec sidekiq
    restart: unless-stopped
    environment:
      SECRET_KEY_BASE: ${SECRET_KEY_BASE}
      POSTGRES_USER: ${POSTGRES_USER:-maybe_user}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: ${POSTGRES_DB:-maybe_production}
      DB_HOST: db
      DB_PORT: 5432
      REDIS_URL: redis://redis:6379/1
      OPENAI_ACCESS_TOKEN: ${OPENAI_ACCESS_TOKEN}
    depends_on:
      redis:
        condition: service_healthy
    networks:
      - maybe_net

  db:
    image: postgres:16
    restart: unless-stopped
    volumes:
      - postgres-data:/var/lib/postgresql/data
    environment:
      POSTGRES_USER: ${POSTGRES_USER:-maybe_user}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: ${POSTGRES_DB:-maybe_production}
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U $$POSTGRES_USER -d $$POSTGRES_DB"]
      interval: 5s
      timeout: 5s
      retries: 5
    networks:
      - maybe_net

  redis:
    image: redis:latest
    restart: unless-stopped
    volumes:
      - redis-data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 5s
      retries: 5
    networks:
      - maybe_net

volumes:
  app-storage:
  postgres-data:
  redis-data:

networks:
  maybe_net:
    driver: bridge
EOF

    log_success "compose.yml created"
}

create_env_file() {
    log_info "Creating .env file..."

    cd "$DEPLOY_DIR"

    if [ -f .env ]; then
        log_warning ".env file already exists, skipping..."
        return
    fi

    # Generate secrets
    SECRET_KEY=$(openssl rand -hex 64)
    DB_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)

    cat > .env << EOF
# Secret key for Rails application
SECRET_KEY_BASE=$SECRET_KEY

# PostgreSQL Configuration
POSTGRES_USER=maybe_user
POSTGRES_PASSWORD=$DB_PASSWORD
POSTGRES_DB=maybe_production

# OpenAI Configuration (Optional - uncomment if needed)
# OPENAI_ACCESS_TOKEN=your_openai_api_key_here
EOF

    log_success ".env file created"
    log_warning "IMPORTANT: Keep your .env file secure!"
}

deploy_app() {
    log_info "Deploying application..."

    cd "$DEPLOY_DIR"

    # Pull additional images
    docker compose pull db redis

    # Start services
    docker compose up -d

    log_success "Application deployed"
}

wait_for_services() {
    log_info "Waiting for services to start..."

    cd "$DEPLOY_DIR"

    # Wait for services
    sleep 10

    # Check health
    docker compose ps

    log_success "Services are running"
}

show_summary() {
    echo ""
    echo "=============================================="
    log_success "Deployment completed successfully! 🎉"
    echo "=============================================="
    echo ""
    echo "📦 Image: $IMAGE_NAME:latest"
    echo "📁 Source: $SOURCE_DIR"
    echo "🚀 Deploy: $DEPLOY_DIR"
    echo "🌐 URL: http://localhost:3000"
    echo ""
    echo "Next steps:"
    echo "  1. Open http://localhost:3000 in your browser"
    echo "  2. Create your first account"
    echo "  3. Start using Maybe!"
    echo ""
    echo "Useful commands:"
    echo "  cd $DEPLOY_DIR"
    echo "  docker compose logs -f          # View logs"
    echo "  docker compose ps               # Check status"
    echo "  docker compose restart          # Restart all"
    echo "  docker compose down             # Stop all"
    echo ""
    echo "To rebuild after code changes:"
    echo "  $SOURCE_DIR/scripts/rebuild-custom.sh"
    echo ""
}

# ==================== MAIN ====================

main() {
    echo ""
    echo "=============================================="
    echo "🚀 Maybe Custom Deployment Setup"
    echo "=============================================="
    echo ""

    check_docker
    setup_source
    build_image
    setup_deploy_dir
    create_compose_file
    create_env_file
    deploy_app
    wait_for_services
    show_summary
}

# Run main function
main

exit 0

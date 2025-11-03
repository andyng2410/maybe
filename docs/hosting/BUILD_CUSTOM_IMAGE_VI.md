# Hướng Dẫn Build Custom Docker Image

Tài liệu này hướng dẫn cách build Docker image từ source code local để deploy các customization của bạn.

## 📋 Mục Lục

1. [Tổng Quan](#tổng-quan)
2. [Prerequisites](#prerequisites)
3. [Build Image Locally](#build-image-locally)
4. [Sử Dụng Custom Image](#sử-dụng-custom-image)
5. [Development Workflow](#development-workflow)
6. [Deploy Custom Image](#deploy-custom-image)
7. [Best Practices](#best-practices)

---

## Tổng Quan

Khi bạn muốn customize code của Maybe, bạn cần:
1. Clone source code về máy
2. Thực hiện các thay đổi
3. Build Docker image mới từ code đã customize
4. Sử dụng image mới này trong Docker Compose

---

## Prerequisites

### 1. Clone Repository

```bash
# Clone repository về máy
git clone https://github.com/maybe-finance/maybe.git
cd maybe

# Hoặc nếu bạn đã fork
git clone https://github.com/your-username/maybe.git
cd maybe
```

### 2. Kiểm Tra Dockerfile

```bash
# Xem nội dung Dockerfile
cat Dockerfile
```

Dự án đã có sẵn `Dockerfile` ở thư mục root.

---

## Build Image Locally

### Phương Pháp 1: Build Trực Tiếp (Khuyến Nghị)

```bash
# Build image với tag custom
docker build -t maybe-custom:latest .

# Build với build args (nếu cần)
docker build \
  --build-arg RUBY_VERSION=3.4.4 \
  --build-arg BUILD_COMMIT_SHA=$(git rev-parse HEAD) \
  -t maybe-custom:latest \
  .
```

**Giải thích:**
- `-t maybe-custom:latest`: Tag cho image của bạn
- `.`: Build context (thư mục hiện tại)
- `--build-arg`: Truyền build arguments

### Phương Pháp 2: Build với Docker Compose

Tạo file `compose.local.yml`:

```yaml
services:
  web:
    build:
      context: .
      dockerfile: Dockerfile
      args:
        RUBY_VERSION: 3.4.4
    image: maybe-custom:latest
    volumes:
      - app-storage:/rails/storage
    ports:
      - 3000:3000
    restart: unless-stopped
    environment:
      <<: *rails_env
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_healthy
    networks:
      - maybe_net

  worker:
    build:
      context: .
      dockerfile: Dockerfile
    image: maybe-custom:latest
    command: bundle exec sidekiq
    restart: unless-stopped
    depends_on:
      redis:
        condition: service_healthy
    environment:
      <<: *rails_env
    networks:
      - maybe_net

  db:
    image: postgres:16
    restart: unless-stopped
    volumes:
      - postgres-data:/var/lib/postgresql/data
    environment:
      <<: *db_env
    healthcheck:
      test: [ "CMD-SHELL", "pg_isready -U $$POSTGRES_USER -d $$POSTGRES_DB" ]
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
      test: [ "CMD", "redis-cli", "ping" ]
      interval: 5s
      timeout: 5s
      retries: 5
    networks:
      - maybe_net

x-db-env: &db_env
  POSTGRES_USER: ${POSTGRES_USER:-maybe_user}
  POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-maybe_password}
  POSTGRES_DB: ${POSTGRES_DB:-maybe_production}

x-rails-env: &rails_env
  <<: *db_env
  SECRET_KEY_BASE: ${SECRET_KEY_BASE}
  SELF_HOSTED: "true"
  RAILS_FORCE_SSL: "false"
  RAILS_ASSUME_SSL: "false"
  DB_HOST: db
  DB_PORT: 5432
  REDIS_URL: redis://redis:6379/1
  OPENAI_ACCESS_TOKEN: ${OPENAI_ACCESS_TOKEN}

volumes:
  app-storage:
  postgres-data:
  redis-data:

networks:
  maybe_net:
    driver: bridge
```

Sau đó build:

```bash
# Build với Docker Compose
docker compose -f compose.local.yml build

# Build với no-cache (build lại từ đầu)
docker compose -f compose.local.yml build --no-cache
```

### Phương Pháp 3: Build với Multi-stage Optimization

Dockerfile đã có sẵn multi-stage build, nhưng bạn có thể customize:

```dockerfile
# Ví dụ: Build với custom stage
docker build --target build -t maybe-build:latest .
docker build --target base -t maybe-base:latest .
```

---

## Sử Dụng Custom Image

### Option 1: Sửa compose.yml Trực Tiếp

Mở file `compose.yml` và thay đổi:

```yaml
# Thay đổi từ:
image: ghcr.io/maybe-finance/maybe:latest

# Thành:
image: maybe-custom:latest
```

### Option 2: Sử Dụng File Compose Riêng

Tạo `compose.custom.yml`:

```yaml
services:
  web:
    image: maybe-custom:latest

  worker:
    image: maybe-custom:latest
```

Chạy với:

```bash
docker compose -f compose.yml -f compose.custom.yml up -d
```

### Option 3: Override với Environment Variable

```bash
# Set environment variable
export MAYBE_IMAGE=maybe-custom:latest

# Sửa compose.yml để dùng variable
# image: ${MAYBE_IMAGE:-ghcr.io/maybe-finance/maybe:latest}

docker compose up -d
```

---

## Development Workflow

### Workflow Chuẩn

```bash
# 1. Clone và setup
git clone https://github.com/your-username/maybe.git
cd maybe

# 2. Tạo branch mới cho feature
git checkout -b feature/my-custom-feature

# 3. Thực hiện thay đổi code
# ... edit files ...

# 4. Test locally (optional - cần setup dev environment)
# bin/setup
# bin/rails test

# 5. Build Docker image
docker build -t maybe-custom:dev .

# 6. Test image
docker run --rm maybe-custom:dev rails --version

# 7. Deploy với Docker Compose
cd ~/maybe-app  # Thư mục deploy của bạn
# Copy source code hoặc mount volume

# 8. Build và run
docker compose -f compose.local.yml build
docker compose -f compose.local.yml up -d

# 9. Xem logs
docker compose logs -f web

# 10. Test ứng dụng
curl http://localhost:3000
```

### Quick Rebuild Workflow

Tạo script `rebuild.sh`:

```bash
#!/bin/bash
set -e

echo "🔨 Building custom image..."
docker build -t maybe-custom:latest .

echo "🔄 Restarting services..."
cd ~/maybe-app
docker compose down
docker compose up -d

echo "📊 Checking status..."
docker compose ps

echo "✅ Done! View logs with: docker compose logs -f"
```

Sử dụng:

```bash
chmod +x rebuild.sh
./rebuild.sh
```

---

## Deploy Custom Image

### Setup Deployment Directory

```bash
# Tạo thư mục deploy riêng
mkdir -p ~/maybe-custom-deploy
cd ~/maybe-custom-deploy

# Copy source code
cp -r ~/maybe/* .

# Tạo compose file
cat > compose.yml << 'EOF'
# Copy nội dung compose.local.yml ở trên
EOF

# Tạo .env
cat > .env << 'EOF'
SECRET_KEY_BASE=your_secret_key
POSTGRES_PASSWORD=your_password
EOF
```

### Build và Deploy

```bash
# Build image
docker build -t maybe-custom:v1.0.0 .

# Tag cho versioning
docker tag maybe-custom:v1.0.0 maybe-custom:latest

# Run
docker compose up -d

# Verify
docker compose ps
docker compose logs -f web
```

### Update Workflow

Khi có thay đổi mới:

```bash
# 1. Pull changes
cd ~/maybe
git pull origin main

# 2. Build new version
docker build -t maybe-custom:v1.0.1 .
docker tag maybe-custom:v1.0.1 maybe-custom:latest

# 3. Deploy update
cd ~/maybe-custom-deploy
docker compose down
docker compose up -d

# 4. Verify
docker compose logs -f web
```

---

## Best Practices

### 1. Versioning

```bash
# Always tag với version
docker build -t maybe-custom:v1.0.0 .
docker tag maybe-custom:v1.0.0 maybe-custom:latest

# Dùng git commit SHA
docker build -t maybe-custom:$(git rev-parse --short HEAD) .
```

### 2. Multi-stage Build Optimization

Dockerfile của Maybe đã optimize sẵn, nhưng bạn có thể cải thiện:

```dockerfile
# Ví dụ: Thêm layer caching cho gems
FROM ruby:3.4.4-slim AS gems
WORKDIR /tmp
COPY Gemfile Gemfile.lock ./
RUN bundle install --jobs 4 --retry 3

# Use cached gems
FROM ruby:3.4.4-slim AS base
COPY --from=gems /usr/local/bundle /usr/local/bundle
```

### 3. .dockerignore

Đảm bảo file `.dockerignore` đã được setup đúng (đã có sẵn trong repo):

```bash
cat .dockerignore
```

### 4. Build Cache

```bash
# Sử dụng build cache
docker build -t maybe-custom:latest .

# Clear cache khi cần
docker build --no-cache -t maybe-custom:latest .

# Sử dụng BuildKit cho build nhanh hơn
DOCKER_BUILDKIT=1 docker build -t maybe-custom:latest .
```

### 5. Health Checks

Thêm health check vào Dockerfile:

```dockerfile
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
  CMD curl -f http://localhost:3000/up || exit 1
```

### 6. Resource Limits

Thêm vào `compose.yml`:

```yaml
services:
  web:
    image: maybe-custom:latest
    deploy:
      resources:
        limits:
          cpus: '2.0'
          memory: 2G
        reservations:
          cpus: '1.0'
          memory: 1G
```

### 7. Logging

```yaml
services:
  web:
    image: maybe-custom:latest
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
```

### 8. Environment-specific Images

```bash
# Development
docker build -t maybe-custom:dev --target build .

# Production
docker build -t maybe-custom:prod .

# Staging
docker build -t maybe-custom:staging --build-arg RAILS_ENV=staging .
```

---

## Ví Dụ Customize Thực Tế

### Ví Dụ 1: Thay Đổi Logo

```bash
# 1. Clone repo
git clone https://github.com/your-username/maybe.git
cd maybe

# 2. Thay đổi logo
# Sửa file: app/views/layouts/_header.html.erb
# Hoặc thay file: app/assets/images/logo.png

# 3. Build image
docker build -t maybe-custom:logo-v1 .

# 4. Deploy
cd ~/maybe-app
# Sửa compose.yml: image: maybe-custom:logo-v1
docker compose down
docker compose up -d
```

### Ví Dụ 2: Thêm Custom CSS

```bash
# 1. Edit CSS
# Sửa file: app/assets/stylesheets/application.tailwind.css

# 2. Build
docker build -t maybe-custom:style-v1 .

# 3. Deploy
docker compose down
docker compose pull  # Skip nếu dùng local image
docker compose up -d
```

### Ví Dụ 3: Thay Đổi Environment Variables

```bash
# 1. Edit Dockerfile thêm ENV
# Hoặc thêm vào .env

# 2. Rebuild
docker build -t maybe-custom:env-v1 .

# 3. Update .env
nano ~/maybe-app/.env

# 4. Restart
docker compose restart
```

---

## Automation Script

Tạo `deploy-custom.sh` cho automation:

```bash
#!/bin/bash
set -e

# Configuration
REPO_DIR="$HOME/maybe"
DEPLOY_DIR="$HOME/maybe-app"
IMAGE_NAME="maybe-custom"
VERSION=$(date +%Y%m%d-%H%M%S)

echo "🚀 Starting custom deployment..."

# 1. Update source
echo "📥 Pulling latest changes..."
cd "$REPO_DIR"
git pull origin main

# 2. Build image
echo "🔨 Building Docker image..."
docker build -t "$IMAGE_NAME:$VERSION" .
docker tag "$IMAGE_NAME:$VERSION" "$IMAGE_NAME:latest"

# 3. Deploy
echo "🎯 Deploying to $DEPLOY_DIR..."
cd "$DEPLOY_DIR"

# Backup current version
docker tag "$IMAGE_NAME:latest" "$IMAGE_NAME:backup-$(date +%Y%m%d)" || true

# Stop current containers
docker compose down

# Start with new image
docker compose up -d

# 4. Verify
echo "✅ Checking deployment..."
sleep 5
docker compose ps

echo "📊 Recent logs:"
docker compose logs --tail=20 web

echo "✅ Deployment complete!"
echo "🌐 Access at: http://localhost:3000"
```

Sử dụng:

```bash
chmod +x deploy-custom.sh
./deploy-custom.sh
```

---

## Troubleshooting

### Build Fails

```bash
# Check Docker daemon
docker info

# Check disk space
df -h

# Check build logs
docker build -t maybe-custom:latest . 2>&1 | tee build.log

# Clean up
docker system prune -a
```

### Image Size Too Large

```bash
# Check image size
docker images maybe-custom

# Use multi-stage build (đã có sẵn)
# Remove cache và rebuild
docker build --no-cache -t maybe-custom:latest .

# Analyze layers
docker history maybe-custom:latest
```

### Container Won't Start

```bash
# Check logs
docker logs <container-id>

# Run interactively để debug
docker run -it --rm maybe-custom:latest /bin/bash

# Check entrypoint
docker inspect maybe-custom:latest | grep -A 10 Entrypoint
```

---

## Tài Nguyên

- [Docker Build Documentation](https://docs.docker.com/engine/reference/commandline/build/)
- [Docker Compose Build](https://docs.docker.com/compose/compose-file/build/)
- [Dockerfile Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- [Multi-stage Builds](https://docs.docker.com/build/building/multi-stage/)

---

**Chúc bạn build thành công! 🎉**

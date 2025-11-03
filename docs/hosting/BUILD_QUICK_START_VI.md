# Quick Start - Build Custom Image

## 🚀 Cách Nhanh Nhất

### Nếu Bạn Đã Có Source Code

```bash
# 1. Di chuyển vào thư mục source code
cd ~/maybe

# 2. Build image
docker build -t maybe-custom:latest .

# 3. Update compose.yml
cd ~/maybe-app
nano compose.yml

# Thay đổi dòng:
# image: ghcr.io/maybe-finance/maybe:latest
# Thành:
# image: maybe-custom:latest

# 4. Restart
docker compose down
docker compose up -d
```

---

## 📦 Setup Từ Đầu

```bash
# 1. Clone source code
git clone https://github.com/maybe-finance/maybe.git ~/maybe
cd ~/maybe

# 2. Customize code (nếu cần)
# ... edit your files ...

# 3. Build image với tag
docker build -t maybe-custom:v1.0.0 .
docker tag maybe-custom:v1.0.0 maybe-custom:latest

# 4. Setup deploy directory
mkdir -p ~/maybe-deploy
cd ~/maybe-deploy

# 5. Tạo compose.yml (sử dụng build local)
cat > compose.yml << 'EOF'
services:
  web:
    build:
      context: /home/YOUR_USER/maybe
      dockerfile: Dockerfile
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

# 6. Tạo .env
cat > .env << EOF
SECRET_KEY_BASE=$(openssl rand -hex 64)
POSTGRES_PASSWORD=$(openssl rand -base64 32)
EOF

# 7. Build và run
docker compose build
docker compose up -d

# 8. Check
docker compose ps
docker compose logs -f
```

---

## 🔄 Workflow Khi Update Code

```bash
# 1. Edit code
cd ~/maybe
# ... make your changes ...

# 2. Rebuild image
docker build -t maybe-custom:latest .

# 3. Restart containers
cd ~/maybe-deploy
docker compose down
docker compose up -d

# 4. Verify
docker compose logs -f web
```

---

## 📝 Script Tự Động

Tạo file `~/rebuild-maybe.sh`:

```bash
#!/bin/bash
set -e

SOURCE_DIR="$HOME/maybe"
DEPLOY_DIR="$HOME/maybe-deploy"

echo "🔨 Building image from $SOURCE_DIR..."
cd "$SOURCE_DIR"
docker build -t maybe-custom:latest .

echo "🔄 Restarting services in $DEPLOY_DIR..."
cd "$DEPLOY_DIR"
docker compose down
docker compose up -d

echo "📊 Status:"
docker compose ps

echo "✅ Done! Logs:"
docker compose logs --tail=20 web
```

Sử dụng:

```bash
chmod +x ~/rebuild-maybe.sh
~/rebuild-maybe.sh
```

---

## 🎯 Các Use Case Thường Gặp

### 1. Customize UI (Logo, Colors, Text)

```bash
cd ~/maybe

# Edit files
# app/views/layouts/_header.html.erb - Header/Logo
# app/assets/stylesheets/ - CSS/Styles
# config/locales/ - Text/Languages

docker build -t maybe-custom:ui-v1 .
cd ~/maybe-deploy
# Update compose.yml: image: maybe-custom:ui-v1
docker compose up -d --force-recreate
```

### 2. Add Custom Features

```bash
cd ~/maybe

# Add your code
# app/models/
# app/controllers/
# app/views/

# Run tests (optional)
bin/rails test

# Build
docker build -t maybe-custom:feature-v1 .

# Deploy
cd ~/maybe-deploy
docker compose down
docker compose up -d
```

### 3. Change Configuration

```bash
cd ~/maybe

# Edit config files
# config/application.rb
# config/environments/production.rb

docker build -t maybe-custom:config-v1 .
cd ~/maybe-deploy
docker compose restart
```

---

## 🐛 Debug Build Issues

### Build quá lâu

```bash
# Dùng BuildKit (nhanh hơn)
DOCKER_BUILDKIT=1 docker build -t maybe-custom:latest .

# Build song song
docker build --build-arg BUILDKIT_INLINE_CACHE=1 -t maybe-custom:latest .
```

### Build lỗi

```bash
# Build với verbose logs
docker build --progress=plain -t maybe-custom:latest . 2>&1 | tee build.log

# Check lỗi cụ thể
grep -i error build.log
```

### Image quá lớn

```bash
# Check size
docker images maybe-custom

# Xem layers
docker history maybe-custom:latest

# Clean up
docker system prune -a
docker builder prune
```

### Container không start

```bash
# Check logs
docker compose logs web

# Run interactive để debug
docker run -it --rm maybe-custom:latest /bin/bash

# Check health
docker compose ps
```

---

## 💡 Tips

### 1. Tag với Version

```bash
# Good practice
docker build -t maybe-custom:$(date +%Y%m%d-%H%M) .
docker tag maybe-custom:$(date +%Y%m%d-%H%M) maybe-custom:latest
```

### 2. Multi-arch Build (ARM64 + AMD64)

```bash
# Nếu cần deploy trên nhiều platform
docker buildx build --platform linux/amd64,linux/arm64 -t maybe-custom:multi .
```

### 3. Build Cache

```bash
# Sử dụng cache từ image khác
docker build --cache-from maybe-custom:latest -t maybe-custom:v2 .
```

### 4. Test Image Trước Khi Deploy

```bash
# Test run
docker run --rm -p 3001:3000 \
  -e SECRET_KEY_BASE=test123 \
  -e DB_HOST=localhost \
  maybe-custom:latest

# Truy cập: http://localhost:3001
```

---

## 📊 Monitoring After Deploy

```bash
# Logs
docker compose logs -f

# Resource usage
docker stats

# Health check
curl http://localhost:3000/up

# Container status
docker compose ps
```

---

## 🔗 Liên Quan

- [BUILD_CUSTOM_IMAGE_VI.md](BUILD_CUSTOM_IMAGE_VI.md) - Hướng dẫn chi tiết
- [HUONG_DAN_DEPLOY_UBUNTU_24LTS.md](HUONG_DAN_DEPLOY_UBUNTU_24LTS.md) - Deploy guide
- [QUICK_REFERENCE_VI.md](QUICK_REFERENCE_VI.md) - Quick commands

---

**Happy Building! 🚀**

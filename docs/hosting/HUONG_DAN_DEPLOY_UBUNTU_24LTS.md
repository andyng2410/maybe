# Hướng Dẫn Deploy Maybe với Docker Compose trên Ubuntu 24 LTS

Tài liệu này hướng dẫn chi tiết cách cài đặt và deploy ứng dụng Maybe (personal finance app) sử dụng Docker Compose trên Ubuntu 24 LTS.

## 📋 Mục Lục

1. [Yêu Cầu Hệ Thống](#yêu-cầu-hệ-thống)
2. [Bước 1: Cài Đặt Docker và Docker Compose](#bước-1-cài-đặt-docker-và-docker-compose)
3. [Bước 2: Chuẩn Bị Môi Trường](#bước-2-chuẩn-bị-môi-trường)
4. [Bước 3: Cấu Hình Ứng Dụng](#bước-3-cấu-hình-ứng-dụng)
5. [Bước 4: Chạy Ứng Dụng](#bước-4-chạy-ứng-dụng)
6. [Bước 5: Cấu Hình Tự Động Khởi Động](#bước-5-cấu-hình-tự-động-khởi-động)
7. [Cập Nhật Ứng Dụng](#cập-nhật-ứng-dụng)
8. [Quản Lý và Bảo Trì](#quản-lý-và-bảo-trì)
9. [Xử Lý Sự Cố](#xử-lý-sự-cố)
10. [Cấu Hình Nâng Cao](#cấu-hình-nâng-cao)

---

## Yêu Cầu Hệ Thống

### Phần Cứng Tối Thiểu
- **CPU**: 2 cores
- **RAM**: 4GB
- **Ổ cứng**: 20GB dung lượng trống
- **Mạng**: Kết nối internet ổn định

### Phần Mềm
- **Hệ điều hành**: Ubuntu 24.04 LTS (64-bit)
- **Quyền truy cập**: Quyền sudo/root
- **Docker**: Phiên bản 24.0 trở lên
- **Docker Compose**: Phiên bản 2.20 trở lên

---

## Bước 1: Cài Đặt Docker và Docker Compose

### 1.1. Cập nhật hệ thống

```bash
# Cập nhật danh sách package
sudo apt update

# Nâng cấp các package đã cài
sudo apt upgrade -y
```

### 1.2. Cài đặt các gói phụ thuộc

```bash
sudo apt install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    apt-transport-https
```

### 1.3. Thêm Docker GPG key

```bash
# Tạo thư mục cho keyrings
sudo install -m 0755 -d /etc/apt/keyrings

# Tải và thêm Docker GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Set quyền cho file key
sudo chmod a+r /etc/apt/keyrings/docker.gpg
```

### 1.4. Thêm Docker repository

```bash
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
```

### 1.5. Cài đặt Docker Engine và Docker Compose

```bash
# Cập nhật lại danh sách package
sudo apt update

# Cài đặt Docker và Docker Compose
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

### 1.6. Kiểm tra cài đặt

```bash
# Kiểm tra Docker version
docker --version

# Kiểm tra Docker Compose version
docker compose version

# Test Docker với hello-world
sudo docker run hello-world
```

Nếu thấy thông báo "Hello from Docker!" thì bạn đã cài đặt thành công!

### 1.7. Cấu hình Docker (Tùy chọn nhưng khuyến nghị)

```bash
# Thêm user hiện tại vào group docker để không cần dùng sudo
sudo usermod -aG docker $USER

# Kích hoạt Docker tự động khởi động cùng hệ thống
sudo systemctl enable docker.service
sudo systemctl enable containerd.service

# Khởi động lại để áp dụng thay đổi group
# Hoặc chạy: newgrp docker
echo "Vui lòng logout và login lại để áp dụng thay đổi group docker"
```

**Lưu ý**: Sau bước này, bạn cần logout và login lại để có thể chạy docker không cần sudo.

---

## Bước 2: Chuẩn Bị Môi Trường

### 2.1. Tạo thư mục cho ứng dụng

```bash
# Tạo thư mục chứa ứng dụng Maybe
mkdir -p ~/maybe-app
cd ~/maybe-app
```

Bạn có thể đặt thư mục ở vị trí khác tùy thích, ví dụ:
- `/opt/maybe` - phù hợp cho production
- `/home/your-user/apps/maybe` - phù hợp cho môi trường dev

### 2.2. Tải file Docker Compose mẫu

```bash
# Tải file compose.yml từ repository
curl -o compose.yml https://raw.githubusercontent.com/maybe-finance/maybe/main/compose.example.yml

# Kiểm tra file đã tải thành công
ls -la
```

Bạn sẽ thấy file `compose.yml` trong thư mục.

### 2.3. Xem cấu trúc Docker Compose

```bash
# Xem nội dung file compose
cat compose.yml
```

File này bao gồm 4 services:
- **web**: Rails application server (port 3000)
- **worker**: Sidekiq background job processor
- **db**: PostgreSQL database
- **redis**: Redis cache và job queue

---

## Bước 3: Cấu Hình Ứng Dụng

### 3.1. Tạo file môi trường .env

```bash
# Tạo file .env
touch .env
```

### 3.2. Tạo SECRET_KEY_BASE

Có 2 cách để tạo secret key:

**Cách 1: Sử dụng openssl**
```bash
openssl rand -hex 64
```

**Cách 2: Không dùng openssl**
```bash
head -c 64 /dev/urandom | od -An -tx1 | tr -d ' \n' && echo
```

Lưu lại chuỗi key được tạo ra để dùng ở bước tiếp theo.

### 3.3. Cấu hình biến môi trường

Mở file `.env` bằng editor yêu thích:

```bash
# Sử dụng nano
nano .env

# Hoặc sử dụng vim
vim .env
```

Thêm nội dung sau vào file `.env`:

```env
# Secret key cho Rails application (QUAN TRỌNG!)
SECRET_KEY_BASE="your_generated_secret_key_from_previous_step"

# PostgreSQL Database Configuration
POSTGRES_USER=maybe_user
POSTGRES_PASSWORD=your_strong_database_password_here
POSTGRES_DB=maybe_production

# OpenAI Configuration (Tùy chọn - chỉ cần nếu dùng AI features)
# OPENAI_ACCESS_TOKEN=your_openai_api_key_here
```

**Lưu ý quan trọng**:
- Thay `your_generated_secret_key_from_previous_step` bằng key bạn đã tạo ở bước 3.2
- Thay `your_strong_database_password_here` bằng mật khẩu mạnh của bạn
- Giữ file `.env` bảo mật, không chia sẻ với người khác
- Nếu không dùng tính năng AI, có thể bỏ qua dòng OPENAI_ACCESS_TOKEN

Lưu file và thoát:
- Với nano: `Ctrl + X`, sau đó `Y`, rồi `Enter`
- Với vim: `ESC`, gõ `:wq`, rồi `Enter`

### 3.4. Kiểm tra file cấu hình

```bash
# Kiểm tra file .env đã được tạo
ls -la

# Xem nội dung (cẩn thận nếu ở môi trường production)
cat .env
```

---

## Bước 4: Chạy Ứng Dụng

### 4.1. Pull Docker images

```bash
# Tải các Docker images cần thiết
docker compose pull
```

Quá trình này sẽ tải:
- Maybe app image từ GHCR
- PostgreSQL 16 image
- Redis latest image

### 4.2. Chạy ứng dụng lần đầu (foreground)

```bash
# Chạy Docker Compose ở chế độ foreground để xem logs
docker compose up
```

Bạn sẽ thấy logs của tất cả services. Đợi cho đến khi thấy thông báo:
```
web_1    | * Listening on http://0.0.0.0:3000
```

### 4.3. Kiểm tra ứng dụng

Mở trình duyệt và truy cập: **http://localhost:3000**

Nếu ứng dụng chạy trên server từ xa, truy cập: **http://your-server-ip:3000**

Bạn sẽ thấy màn hình đăng nhập của Maybe.

### 4.4. Tạo tài khoản đầu tiên

1. Click vào "Create your account"
2. Nhập email và password
3. Đăng nhập vào ứng dụng

### 4.5. Dừng ứng dụng và chạy background

Nếu ứng dụng chạy OK, bạn có thể dừng lại bằng `Ctrl + C`, sau đó chạy ở background:

```bash
# Chạy ở chế độ detached (background)
docker compose up -d
```

### 4.6. Kiểm tra trạng thái containers

```bash
# Xem danh sách containers đang chạy
docker compose ps

# Xem logs
docker compose logs

# Xem logs của một service cụ thể
docker compose logs web
docker compose logs worker
docker compose logs db

# Theo dõi logs real-time
docker compose logs -f
```

---

## Bước 5: Cấu Hình Tự Động Khởi Động

Để ứng dụng tự động khởi động khi server reboot:

### 5.1. Tạo systemd service

```bash
# Tạo file service
sudo nano /etc/systemd/system/maybe-app.service
```

Thêm nội dung sau:

```ini
[Unit]
Description=Maybe Personal Finance App
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/home/YOUR_USERNAME/maybe-app
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
```

**Lưu ý**: Thay `/home/YOUR_USERNAME/maybe-app` bằng đường dẫn thực tế của bạn.

### 5.2. Enable và start service

```bash
# Reload systemd
sudo systemctl daemon-reload

# Enable service tự động khởi động
sudo systemctl enable maybe-app.service

# Start service
sudo systemctl start maybe-app.service

# Kiểm tra trạng thái
sudo systemctl status maybe-app.service
```

### 5.3. Test reboot

```bash
# Reboot server để test
sudo reboot

# Sau khi reboot, kiểm tra containers
docker compose ps
```

---

## Cập Nhật Ứng Dụng

### Cập nhật lên phiên bản mới nhất

```bash
# Di chuyển vào thư mục ứng dụng
cd ~/maybe-app

# Pull image mới nhất
docker compose pull

# Rebuild và restart
docker compose build
docker compose up --no-deps -d web worker

# Kiểm tra logs
docker compose logs -f web
```

### Chuyển sang phiên bản stable

Mặc định, `compose.yml` sử dụng tag `latest`. Để dùng phiên bản ổn định hơn:

```bash
# Sửa file compose.yml
nano compose.yml
```

Thay đổi dòng:
```yaml
image: ghcr.io/maybe-finance/maybe:latest
```

Thành:
```yaml
image: ghcr.io/maybe-finance/maybe:stable
```

Sau đó chạy update:
```bash
docker compose pull
docker compose up --no-deps -d web worker
```

---

## Quản Lý và Bảo Trì

### Các lệnh quản lý cơ bản

```bash
# Khởi động ứng dụng
docker compose up -d

# Dừng ứng dụng
docker compose down

# Dừng và xóa volumes (XÓA DỮ LIỆU!)
docker compose down -v

# Restart một service cụ thể
docker compose restart web
docker compose restart worker

# Xem resource usage
docker stats

# Xem logs
docker compose logs -f --tail=100

# Exec vào container
docker compose exec web bash
docker compose exec db psql -U maybe_user -d maybe_production
```

### Backup dữ liệu

#### Backup PostgreSQL database

```bash
# Tạo thư mục backup
mkdir -p ~/maybe-backups

# Backup database
docker compose exec -T db pg_dump -U maybe_user -d maybe_production > ~/maybe-backups/maybe_backup_$(date +%Y%m%d_%H%M%S).sql

# Backup với compression
docker compose exec -T db pg_dump -U maybe_user -d maybe_production | gzip > ~/maybe-backups/maybe_backup_$(date +%Y%m%d_%H%M%S).sql.gz
```

#### Restore database

```bash
# Restore từ backup (CHÚ Ý: sẽ ghi đè dữ liệu hiện tại)
docker compose exec -T db psql -U maybe_user -d maybe_production < ~/maybe-backups/maybe_backup_20250101_120000.sql

# Restore từ backup đã nén
gunzip < ~/maybe-backups/maybe_backup_20250101_120000.sql.gz | docker compose exec -T db psql -U maybe_user -d maybe_production
```

#### Tự động backup với cron

```bash
# Mở crontab
crontab -e

# Thêm dòng sau để backup hàng ngày lúc 2:00 AM
0 2 * * * cd ~/maybe-app && docker compose exec -T db pg_dump -U maybe_user -d maybe_production | gzip > ~/maybe-backups/maybe_backup_$(date +\%Y\%m\%d_\%H\%M\%S).sql.gz

# Thêm dòng sau để xóa backup cũ hơn 30 ngày
0 3 * * * find ~/maybe-backups -name "maybe_backup_*.sql.gz" -mtime +30 -delete
```

### Xem thông tin hệ thống

```bash
# Xem disk usage của Docker
docker system df

# Dọn dẹp Docker (containers, images, volumes không dùng)
docker system prune -a

# Dọn dẹp volumes không dùng
docker volume prune

# Xem logs của PostgreSQL
docker compose logs db

# Xem logs của Redis
docker compose logs redis
```

---

## Xử Lý Sự Cố

### Lỗi: Container không start

```bash
# Kiểm tra logs chi tiết
docker compose logs web
docker compose logs db

# Kiểm tra trạng thái services
docker compose ps

# Restart tất cả
docker compose restart
```

### Lỗi: ActiveRecord::DatabaseConnectionError

Nếu gặp lỗi kết nối database lần đầu chạy:

```bash
# Dừng tất cả containers
docker compose down

# Xóa volume database (CẢNH BÁO: mất dữ liệu!)
docker volume rm maybe-app_postgres-data

# Khởi động lại
docker compose up -d

# Kiểm tra database connection
docker compose exec db psql -U maybe_user -d maybe_production -c "SELECT 1;"
```

### Lỗi: Port 3000 đã được sử dụng

```bash
# Kiểm tra process đang dùng port 3000
sudo lsof -i :3000

# Hoặc
sudo netstat -tulpn | grep :3000

# Kill process nếu cần
sudo kill -9 <PID>

# Hoặc thay đổi port trong compose.yml
# Sửa dòng "3000:3000" thành "8080:3000"
```

### Ứng dụng chậm hoặc không phản hồi

```bash
# Kiểm tra resource usage
docker stats

# Kiểm tra logs
docker compose logs -f web

# Restart worker
docker compose restart worker

# Tăng memory limit (sửa compose.yml)
# Thêm vào service web:
#   deploy:
#     resources:
#       limits:
#         memory: 2G
```

### Reset hoàn toàn ứng dụng

**CẢNH BÁO: Lệnh này sẽ xóa TẤT CẢ dữ liệu!**

```bash
# Dừng và xóa tất cả
docker compose down -v

# Xóa images
docker compose down --rmi all

# Khởi động lại từ đầu
docker compose up -d
```

---

## Cấu Hình Nâng Cao

### 1. Cấu hình Reverse Proxy với Nginx

Nếu bạn muốn expose ứng dụng ra internet với domain name:

#### Cài đặt Nginx

```bash
sudo apt install -y nginx
```

#### Tạo Nginx config

```bash
sudo nano /etc/nginx/sites-available/maybe
```

Thêm nội dung:

```nginx
server {
    listen 80;
    server_name your-domain.com;

    location / {
        proxy_pass http://localhost:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

Enable site:

```bash
sudo ln -s /etc/nginx/sites-available/maybe /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
```

### 2. Cài đặt SSL với Let's Encrypt

```bash
# Cài đặt Certbot
sudo apt install -y certbot python3-certbot-nginx

# Lấy SSL certificate
sudo certbot --nginx -d your-domain.com

# Auto-renew
sudo systemctl enable certbot.timer
```

### 3. Cấu hình Firewall (UFW)

```bash
# Enable UFW
sudo ufw enable

# Allow SSH
sudo ufw allow ssh

# Allow HTTP và HTTPS
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Chặn truy cập trực tiếp vào port 3000 từ bên ngoài
# (chỉ cho phép từ localhost nếu dùng Nginx)
sudo ufw deny 3000/tcp

# Kiểm tra status
sudo ufw status
```

### 4. Monitoring với Docker Stats và Logs

Tạo script monitoring:

```bash
nano ~/monitor-maybe.sh
```

Nội dung:

```bash
#!/bin/bash
echo "=== Maybe App Status ==="
docker compose -f ~/maybe-app/compose.yml ps
echo ""
echo "=== Resource Usage ==="
docker stats --no-stream
echo ""
echo "=== Recent Logs (last 20 lines) ==="
docker compose -f ~/maybe-app/compose.yml logs --tail=20
```

Cho phép execute:

```bash
chmod +x ~/monitor-maybe.sh
```

Chạy:

```bash
~/monitor-maybe.sh
```

### 5. Environment Variables mở rộng

Bạn có thể thêm các biến môi trường sau vào `.env`:

```env
# Rails Environment
RAILS_ENV=production
RAILS_LOG_LEVEL=info

# Email Configuration (nếu cần gửi email)
SMTP_ADDRESS=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=your-email@gmail.com
SMTP_PASSWORD=your-app-password
SMTP_DOMAIN=gmail.com

# App Configuration
APP_HOST=your-domain.com
APP_PROTOCOL=https
```

---

## Checklist Triển Khai

- [ ] Cài đặt Docker và Docker Compose
- [ ] Tạo thư mục ứng dụng
- [ ] Tải file compose.yml
- [ ] Tạo file .env với SECRET_KEY_BASE và POSTGRES_PASSWORD
- [ ] Pull Docker images
- [ ] Chạy ứng dụng lần đầu và kiểm tra
- [ ] Tạo tài khoản admin
- [ ] Cấu hình chạy background với docker compose up -d
- [ ] Setup systemd service cho auto-start (tùy chọn)
- [ ] Cấu hình Nginx reverse proxy (nếu cần)
- [ ] Cài đặt SSL certificate (nếu cần)
- [ ] Setup firewall
- [ ] Cấu hình backup tự động
- [ ] Test restore backup
- [ ] Document thông tin đăng nhập và credentials

---

## Tài Nguyên Tham Khảo

- [Docker Documentation](https://docs.docker.com/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Maybe GitHub Repository](https://github.com/maybe-finance/maybe)
- [Maybe Official Docker Guide](https://github.com/maybe-finance/maybe/blob/main/docs/hosting/docker.md)
- [Ubuntu 24.04 LTS Documentation](https://ubuntu.com/server/docs)

---

## Hỗ Trợ

Nếu gặp vấn đề:
1. Kiểm tra logs: `docker compose logs -f`
2. Kiểm tra GitHub Issues: https://github.com/maybe-finance/maybe/issues
3. Tham gia GitHub Discussions: https://github.com/maybe-finance/maybe/discussions

---

**Chúc bạn deploy thành công! 🚀**

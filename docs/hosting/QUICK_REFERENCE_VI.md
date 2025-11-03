# Quick Reference - Các Lệnh Thường Dùng

## 🚀 Cài Đặt Nhanh

```bash
# 1. Cài Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# 2. Setup Maybe
mkdir -p ~/maybe-app && cd ~/maybe-app
curl -o compose.yml https://raw.githubusercontent.com/maybe-finance/maybe/main/compose.example.yml

# 3. Tạo .env
echo 'SECRET_KEY_BASE="'$(openssl rand -hex 64)'"' > .env
echo 'POSTGRES_PASSWORD="'$(openssl rand -base64 32)'"' >> .env

# 4. Chạy ứng dụng
docker compose up -d
```

Truy cập: http://localhost:3000

---

## 📝 Quản Lý Cơ Bản

```bash
# Khởi động
docker compose up -d

# Dừng
docker compose down

# Restart
docker compose restart

# Xem logs
docker compose logs -f

# Xem trạng thái
docker compose ps

# Xem resource usage
docker stats
```

---

## 🔄 Cập Nhật

```bash
cd ~/maybe-app
docker compose pull
docker compose up --no-deps -d web worker
```

---

## 💾 Backup & Restore

### Backup

```bash
# Backup database
docker compose exec -T db pg_dump -U maybe_user -d maybe_production | \
  gzip > backup_$(date +%Y%m%d).sql.gz
```

### Restore

```bash
# Restore database
gunzip < backup_20250101.sql.gz | \
  docker compose exec -T db psql -U maybe_user -d maybe_production
```

---

## 🔧 Troubleshooting

```bash
# Xem logs chi tiết
docker compose logs web --tail=100

# Restart một service
docker compose restart web

# Reset database (XÓA DỮ LIỆU!)
docker compose down
docker volume rm maybe-app_postgres-data
docker compose up -d

# Kiểm tra database connection
docker compose exec db psql -U maybe_user -d maybe_production -c "SELECT 1;"

# Xem port đang dùng
sudo lsof -i :3000
```

---

## 🧹 Bảo Trì

```bash
# Dọn dẹp Docker
docker system prune -a

# Xóa volumes không dùng
docker volume prune

# Xem disk usage
docker system df

# Exec vào container
docker compose exec web bash
docker compose exec db psql -U maybe_user -d maybe_production
```

---

## 🔐 Security

```bash
# Firewall setup
sudo ufw enable
sudo ufw allow ssh
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# SSL với Let's Encrypt
sudo apt install certbot python3-certbot-nginx
sudo certbot --nginx -d your-domain.com
```

---

## 📊 Monitoring

```bash
# Xem logs real-time
docker compose logs -f web

# Xem resource usage
docker stats

# Health check
curl http://localhost:3000/up
```

---

## 🔄 Cron Jobs

### Auto backup hàng ngày

```bash
# Thêm vào crontab
crontab -e

# Backup lúc 2 AM hàng ngày
0 2 * * * cd ~/maybe-app && docker compose exec -T db pg_dump -U maybe_user -d maybe_production | gzip > ~/backups/maybe_$(date +\%Y\%m\%d).sql.gz

# Xóa backup cũ hơn 30 ngày
0 3 * * * find ~/backups -name "maybe_*.sql.gz" -mtime +30 -delete
```

---

## 📂 File Paths

```
~/maybe-app/
├── compose.yml          # Docker Compose config
├── .env                 # Environment variables (GIỮ BÍ MẬT!)
└── backups/             # Thư mục backup (tự tạo)
```

---

## 🆘 Emergency Commands

```bash
# Dừng tất cả containers
docker stop $(docker ps -aq)

# Xóa tất cả containers
docker rm $(docker ps -aq)

# Reset hoàn toàn (MẤT DỮ LIỆU!)
docker compose down -v --rmi all
docker system prune -a --volumes
```

---

## 🌐 Production URLs

- **Local**: http://localhost:3000
- **Server**: http://your-server-ip:3000
- **Domain**: https://your-domain.com (sau khi setup Nginx + SSL)

---

## 📞 Support

- GitHub Issues: https://github.com/maybe-finance/maybe/issues
- Documentation: https://github.com/maybe-finance/maybe

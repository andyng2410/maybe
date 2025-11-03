# Maybe Custom Build Scripts

Collection of useful scripts for building and deploying custom Maybe Docker images.

## 📜 Scripts

### 1. `deploy-custom.sh`

**Mục đích**: Setup và deploy Maybe với custom image lần đầu tiên

**Sử dụng**:
```bash
cd ~/maybe
chmod +x scripts/deploy-custom.sh
./scripts/deploy-custom.sh
```

**Chức năng**:
- ✅ Kiểm tra Docker installation
- ✅ Clone/update source code
- ✅ Build Docker image
- ✅ Tạo deployment directory
- ✅ Tạo docker-compose.yml
- ✅ Tạo .env với secrets
- ✅ Deploy application

**Environment Variables**:
```bash
SOURCE_DIR=$HOME/maybe              # Source code directory
DEPLOY_DIR=$HOME/maybe-deploy       # Deployment directory
IMAGE_NAME=maybe-custom             # Docker image name
```

---

### 2. `rebuild-custom.sh`

**Mục đích**: Rebuild và restart application sau khi thay đổi code

**Sử dụng**:
```bash
cd ~/maybe
chmod +x scripts/rebuild-custom.sh
./scripts/rebuild-custom.sh
```

**Chức năng**:
- ✅ Kiểm tra directories
- ✅ Backup current image
- ✅ Build new image
- ✅ Restart services
- ✅ Health check

**Environment Variables**:
```bash
SOURCE_DIR=$HOME/maybe              # Source code directory
DEPLOY_DIR=$HOME/maybe-app          # Deployment directory
IMAGE_NAME=maybe-custom             # Docker image name
VERSION=latest                      # Image version tag
```

---

### 3. `backup-before-rebuild.sh`

**Mục đích**: Backup database, image và volumes trước khi rebuild

**Sử dụng**:
```bash
cd ~/maybe
chmod +x scripts/backup-before-rebuild.sh
./scripts/backup-before-rebuild.sh
```

**Chức năng**:
- ✅ Backup PostgreSQL database
- ✅ Backup Docker image
- ✅ Backup volumes (app-storage)
- ✅ Backup .env file
- ✅ Cleanup old backups (>30 days)

**Environment Variables**:
```bash
DEPLOY_DIR=$HOME/maybe-app          # Deployment directory
BACKUP_DIR=$HOME/maybe-backups      # Backup directory
IMAGE_NAME=maybe-custom             # Docker image name
```

---

## 🚀 Typical Workflows

### First Time Setup

```bash
# 1. Make scripts executable
chmod +x scripts/*.sh

# 2. Deploy
./scripts/deploy-custom.sh

# Wait for completion, then access: http://localhost:3000
```

### Making Code Changes

```bash
# 1. Make your changes
cd ~/maybe
# ... edit code ...

# 2. Backup (optional but recommended)
./scripts/backup-before-rebuild.sh

# 3. Rebuild and deploy
./scripts/rebuild-custom.sh

# 4. Verify
curl http://localhost:3000
```

### Scheduled Backups

Add to crontab:

```bash
crontab -e

# Add this line for daily backup at 2 AM:
0 2 * * * $HOME/maybe/scripts/backup-before-rebuild.sh >> $HOME/maybe-backups/backup.log 2>&1
```

---

## 🎯 Examples

### Custom Environment Variables

```bash
# Deploy to different directory
SOURCE_DIR=/opt/maybe \
DEPLOY_DIR=/opt/maybe-deploy \
./scripts/deploy-custom.sh

# Rebuild with custom image name
IMAGE_NAME=my-maybe-app \
VERSION=v2.0.0 \
./scripts/rebuild-custom.sh

# Backup to different location
BACKUP_DIR=/mnt/backups/maybe \
./scripts/backup-before-rebuild.sh
```

### Quick Aliases

Add to `~/.bashrc`:

```bash
# Maybe shortcuts
alias maybe-deploy='cd ~/maybe && ./scripts/deploy-custom.sh'
alias maybe-rebuild='cd ~/maybe && ./scripts/rebuild-custom.sh'
alias maybe-backup='cd ~/maybe && ./scripts/backup-before-rebuild.sh'
alias maybe-logs='cd ~/maybe-app && docker compose logs -f'
alias maybe-status='cd ~/maybe-app && docker compose ps'
```

Then:

```bash
source ~/.bashrc
maybe-rebuild
```

---

## 🔧 Customization

### Modify Scripts

All scripts support environment variables. Create a config file:

**`~/maybe-config.env`**:
```bash
export SOURCE_DIR="$HOME/projects/maybe"
export DEPLOY_DIR="/opt/maybe-production"
export BACKUP_DIR="/mnt/backup/maybe"
export IMAGE_NAME="maybe-production"
```

Then source before running:

```bash
source ~/maybe-config.env
./scripts/rebuild-custom.sh
```

### Add to System PATH

```bash
# Create symlinks in ~/bin
mkdir -p ~/bin
ln -s ~/maybe/scripts/deploy-custom.sh ~/bin/maybe-deploy
ln -s ~/maybe/scripts/rebuild-custom.sh ~/bin/maybe-rebuild
ln -s ~/maybe/scripts/backup-before-rebuild.sh ~/bin/maybe-backup

# Add to PATH if not already
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# Now you can run from anywhere:
maybe-rebuild
```

---

## 📊 Monitoring After Deploy

```bash
# View logs
cd ~/maybe-app
docker compose logs -f

# Check status
docker compose ps

# Resource usage
docker stats

# Health check
curl http://localhost:3000/up
```

---

## 🐛 Troubleshooting

### Script Permission Denied

```bash
chmod +x scripts/*.sh
```

### Docker Permission Denied

```bash
sudo usermod -aG docker $USER
newgrp docker
# Or logout and login again
```

### Source Directory Not Found

```bash
# Make sure source code is cloned
git clone https://github.com/maybe-finance/maybe.git ~/maybe

# Or set correct path
SOURCE_DIR=/path/to/maybe ./scripts/rebuild-custom.sh
```

### Deploy Directory Not Found

```bash
# First time: use deploy-custom.sh
./scripts/deploy-custom.sh

# Or create manually
mkdir -p ~/maybe-app
```

---

## 📚 Related Documentation

- [BUILD_CUSTOM_IMAGE_VI.md](../docs/hosting/BUILD_CUSTOM_IMAGE_VI.md) - Chi tiết về build custom image
- [BUILD_QUICK_START_VI.md](../docs/hosting/BUILD_QUICK_START_VI.md) - Quick start guide
- [HUONG_DAN_DEPLOY_UBUNTU_24LTS.md](../docs/hosting/HUONG_DAN_DEPLOY_UBUNTU_24LTS.md) - Deploy guide
- [QUICK_REFERENCE_VI.md](../docs/hosting/QUICK_REFERENCE_VI.md) - Command reference

---

## 🤝 Contributing

Feel free to improve these scripts! Common improvements:

- Add more error handling
- Support for more backup types
- Integration with cloud storage
- Notification systems (email, Slack)
- Monitoring integrations

---

## 📄 License

These scripts are part of the Maybe project and follow the same AGPLv3 license.

---

**Happy Building! 🚀**

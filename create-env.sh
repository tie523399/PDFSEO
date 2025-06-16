#!/bin/bash

# 創建 .env 檔案的腳本

# 顏色定義
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}正在創建 .env 檔案...${NC}"

# 提示用戶輸入配置
read -p "請輸入服務器 IP 地址: " SERVER_IP
read -p "請輸入 Telegram Bot Token (可選，按 Enter 跳過): " TELEGRAM_BOT_TOKEN
read -p "請輸入 Telegram 管理員 ID (可選，按 Enter 跳過): " TELEGRAM_ADMIN_IDS

# 創建 .env 檔案
cat > /var/www/pdfmaster/.env << EOF
# PDF Master 配置
# 自動生成於: $(date)

# 域名
DOMAIN=vectorized.cc
WWW_DOMAIN=www.vectorized.cc
SERVER_IP=${SERVER_IP}

# SSL
SSL_EMAIL=admin@vectorized.cc

# API
API_PORT=3000

# Telegram Bot 設定
TELEGRAM_BOT_TOKEN=${TELEGRAM_BOT_TOKEN:-YOUR_BOT_TOKEN_HERE}
TELEGRAM_ADMIN_IDS=${TELEGRAM_ADMIN_IDS:-YOUR_TELEGRAM_ID_HERE}
TELEGRAM_WEBHOOK_URL=https://vectorized.cc/api/telegram/webhook

# 應用程式設定
APP_ENV=production
APP_DEBUG=false
APP_URL=https://vectorized.cc

# 日誌設定
LOG_LEVEL=info
LOG_PATH=/var/log/pdfmaster

# 安全設定
SESSION_SECRET=$(openssl rand -base64 32)
JWT_SECRET=$(openssl rand -base64 32)

# 資料庫設定（如果需要）
# DB_CONNECTION=sqlite
# DB_DATABASE=/var/www/pdfmaster/database.sqlite

# Redis 設定（如果需要）
# REDIS_HOST=127.0.0.1
# REDIS_PORT=6379
# REDIS_PASSWORD=

# 備份設定
BACKUP_ENABLED=true
BACKUP_PATH=/var/backups/pdfmaster
BACKUP_RETENTION_DAYS=7
EOF

# 設置正確的權限
chmod 600 /var/www/pdfmaster/.env
chown www-data:www-data /var/www/pdfmaster/.env

echo -e "${GREEN}.env 檔案已創建完成！${NC}"
echo -e "${YELLOW}檔案位置: /var/www/pdfmaster/.env${NC}"
echo ""
echo "您可以使用以下命令編輯 .env 檔案："
echo "nano /var/www/pdfmaster/.env" 
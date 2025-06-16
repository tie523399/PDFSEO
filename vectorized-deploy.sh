#!/bin/bash

# Vectorized.cc PDF Master 一鍵部署腳本 - 最終版本
# 所有配置已固定，無需任何輸入

set -e

# 固定配置
DOMAIN="vectorized.cc"
REPO_URL="https://github.com/tie523399/PDFSEO.git"
TELEGRAM_BOT_TOKEN="7002177842:AAE7cXJpmqXKmZAh19aef2P4dfnxW0GVjZs"
TELEGRAM_CHAT_ID="7341258916"
APP_DIR="/var/www/pdfmaster"

# 顏色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== Vectorized.cc PDF Master 部署開始 ===${NC}"

# 檢查是否為 root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}錯誤: 請使用 sudo 運行此腳本${NC}"
   exit 1
fi

# 更新系統
echo -e "${YELLOW}更新系統...${NC}"
apt update && apt upgrade -y

# 安裝必要軟體
echo -e "${YELLOW}安裝必要軟體...${NC}"
apt install -y nginx git curl wget certbot python3-certbot-nginx

# 創建應用目錄
echo -e "${YELLOW}創建應用目錄...${NC}"
mkdir -p $APP_DIR
mkdir -p /var/www/certbot
mkdir -p /var/log
mkdir -p /var/backups/pdfmaster

# 克隆或更新代碼
echo -e "${YELLOW}部署應用程式...${NC}"
if [ -d "$APP_DIR/.git" ]; then
    cd $APP_DIR
    # 解決 Git 安全目錄問題
    git config --global --add safe.directory $APP_DIR
    git pull origin main
else
    git clone $REPO_URL $APP_DIR
    cd $APP_DIR
    # 解決 Git 安全目錄問題
    git config --global --add safe.directory $APP_DIR
fi

# 設置權限
chown -R www-data:www-data $APP_DIR
chmod -R 755 $APP_DIR

# 創建 Nginx 配置
echo -e "${YELLOW}配置 Nginx...${NC}"
cat > /etc/nginx/sites-available/pdfmaster << 'EOF'
# PDF Master 主配置
server {
    listen 80;
    server_name vectorized.cc www.vectorized.cc;
    
    root /var/www/pdfmaster;
    index index.html;
    
    # Let's Encrypt 驗證
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
        try_files $uri =404;
    }
    
    location / {
        try_files $uri $uri/ /index.html;
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header X-XSS-Protection "1; mode=block" always;
    }
    
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|pdf|woff|woff2|ttf|svg)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        access_log off;
    }
    
    location /api {
        proxy_pass http://localhost:3001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
    
    location /health {
        access_log off;
        return 200 "OK\n";
        add_header Content-Type text/plain;
    }
}

# 條件包含 SSL 配置
include /etc/nginx/sites-available/pdfmaster-ssl-active.conf;
EOF

# 創建空的 SSL 配置（避免 include 錯誤）
echo "# SSL 配置將在獲取證書後自動生成" > /etc/nginx/sites-available/pdfmaster-ssl-active.conf

# 啟用網站
ln -sf /etc/nginx/sites-available/pdfmaster /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# 測試並重啟 Nginx
nginx -t && systemctl restart nginx

# 獲取 SSL 證書
echo -e "${YELLOW}獲取 SSL 證書...${NC}"
certbot certonly --webroot -w /var/www/certbot -d $DOMAIN -d www.$DOMAIN --non-interactive --agree-tos --email admin@$DOMAIN

# 如果證書獲取成功，創建 SSL 配置
if [ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]; then
    echo -e "${GREEN}SSL 證書獲取成功，配置 HTTPS...${NC}"
    
    cat > /etc/nginx/sites-available/pdfmaster-ssl-active.conf << 'EOF'
# SSL 配置
server {
    listen 443 ssl http2;
    server_name vectorized.cc www.vectorized.cc;
    
    root /var/www/pdfmaster;
    index index.html;
    
    ssl_certificate /etc/letsencrypt/live/vectorized.cc/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/vectorized.cc/privkey.pem;
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    
    location / {
        try_files $uri $uri/ /index.html;
    }
    
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|pdf|woff|woff2|ttf|svg)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        access_log off;
    }
    
    location /api {
        proxy_pass http://localhost:3001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}

# HTTP 到 HTTPS 重定向
server {
    listen 80;
    server_name vectorized.cc www.vectorized.cc;
    
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
        try_files $uri =404;
    }
    
    location / {
        return 301 https://$server_name$request_uri;
    }
}
EOF
    
    # 重啟 Nginx
    nginx -t && systemctl reload nginx
fi

# 安裝自動更新系統
echo -e "${YELLOW}安裝自動更新系統...${NC}"

# 複製自動更新腳本
cp $APP_DIR/auto-update.sh /usr/local/bin/
chmod +x /usr/local/bin/auto-update.sh

# 創建 systemd 服務
cat > /etc/systemd/system/pdfmaster-updater.service << EOF
[Unit]
Description=PDF Master Auto Updater
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/auto-update.sh
StandardOutput=journal
StandardError=journal
User=root
PrivateTmp=true
NoNewPrivileges=true
Environment="TELEGRAM_BOT_TOKEN=$TELEGRAM_BOT_TOKEN"
Environment="TELEGRAM_CHAT_ID=$TELEGRAM_CHAT_ID"
EOF

# 創建 systemd timer
cat > /etc/systemd/system/pdfmaster-updater.timer << 'EOF'
[Unit]
Description=Run PDF Master Auto Updater every 30 minutes
Requires=pdfmaster-updater.service

[Timer]
OnCalendar=*:0/30
OnBootSec=5min
Persistent=true

[Install]
WantedBy=timers.target
EOF

# 啟動自動更新
systemctl daemon-reload
systemctl enable pdfmaster-updater.timer
systemctl start pdfmaster-updater.timer

# 設置防火牆
echo -e "${YELLOW}配置防火牆...${NC}"
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

# 發送 Telegram 通知
curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
    -d "chat_id=$TELEGRAM_CHAT_ID" \
    -d "text=✅ Vectorized.cc 部署完成！

🌐 網站: https://vectorized.cc
📁 目錄: $APP_DIR
🔄 自動更新: 每30分鐘檢查
📊 狀態: 運行中" &>/dev/null

echo -e "${GREEN}=== 部署完成！===${NC}"
echo ""
echo -e "${GREEN}網站已部署到: https://$DOMAIN${NC}"
echo ""
echo "有用的命令:"
echo "查看更新日誌: tail -f /var/log/pdfmaster-update.log"
echo "手動更新: systemctl start pdfmaster-updater.service"
echo "查看自動更新狀態: systemctl status pdfmaster-updater.timer"
echo "查看 Nginx 狀態: systemctl status nginx" 
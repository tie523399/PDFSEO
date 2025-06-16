#!/bin/bash

# PDF Master 從 Git 部署腳本 - Ubuntu 22.04 x64
# 域名: vectorized.cc
# 功能: 從 GitHub 拉取專案並自動部署

set -e  # 遇到錯誤立即退出

# 顏色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 配置變數
DOMAIN="vectorized.cc"
WWW_DOMAIN="www.vectorized.cc"
APP_DIR="/var/www/pdfmaster"
NGINX_CONF="/etc/nginx/sites-available/pdfmaster"
EMAIL="admin@vectorized.cc"
GIT_REPO="https://github.com/tie523399/PDFSEO.git"  # Git 倉庫地址
BRANCH="main"  # 分支名稱

# 打印帶顏色的訊息
print_message() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

print_error() {
    echo -e "${RED}[錯誤]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[警告]${NC} $1"
}

# 檢查是否為 root 用戶
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "此腳本必須以 root 權限運行"
        exit 1
    fi
}

# 更新系統
update_system() {
    print_message "正在更新系統套件..."
    apt update -y
    apt upgrade -y
}

# 安裝必要的軟體
install_dependencies() {
    print_message "正在安裝必要的軟體..."
    apt install -y nginx certbot python3-certbot-nginx git curl wget unzip
    apt install -y nodejs npm  # 如果需要 Node.js 環境
}

# 從 Git 克隆專案
clone_from_git() {
    print_message "正在從 Git 獲取專案..."
    
    # 如果目錄已存在，先備份
    if [ -d "$APP_DIR" ]; then
        print_warning "應用程式目錄已存在，正在備份..."
        mv $APP_DIR ${APP_DIR}_backup_$(date +%Y%m%d_%H%M%S)
    fi
    
    # 創建目錄並克隆專案
    mkdir -p $(dirname $APP_DIR)
    cd $(dirname $APP_DIR)
    
    # 克隆專案
    git clone -b $BRANCH $GIT_REPO $(basename $APP_DIR)
    
    # 進入專案目錄
    cd $APP_DIR
    
    # 設置正確的權限
    chown -R www-data:www-data $APP_DIR
    chmod -R 755 $APP_DIR
    
    print_message "專案克隆完成！"
}

# 創建 .env 檔案
create_env_file() {
    print_message "正在創建 .env 檔案..."
    
    # 提示用戶輸入配置
    read -p "請輸入服務器 IP 地址: " SERVER_IP
    read -p "請輸入 Telegram Bot Token (可選，按 Enter 跳過): " TELEGRAM_BOT_TOKEN
    read -p "請輸入 Telegram 管理員 ID (可選，按 Enter 跳過): " TELEGRAM_ADMIN_IDS
    
    # 創建 .env 檔案
    cat > $APP_DIR/.env << EOF
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

# 備份設定
BACKUP_ENABLED=true
BACKUP_PATH=/var/backups/pdfmaster
BACKUP_RETENTION_DAYS=7
EOF
    
    # 設置正確的權限
    chmod 600 $APP_DIR/.env
    chown www-data:www-data $APP_DIR/.env
    
    print_message ".env 檔案創建完成！"
}

# 配置 Nginx
configure_nginx() {
    print_message "正在配置 Nginx..."
    
    # 創建 Nginx 配置檔案
    cat > $NGINX_CONF << 'EOF'
# PDF Master Nginx 配置
# 自動生成於: $(date)

# HTTP 重定向到 HTTPS
server {
    listen 80;
    listen [::]:80;
    server_name vectorized.cc www.vectorized.cc;
    
    # Let's Encrypt 驗證目錄
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }
    
    # 重定向所有 HTTP 請求到 HTTPS
    location / {
        return 301 https://$server_name$request_uri;
    }
}

# HTTPS 配置
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name vectorized.cc www.vectorized.cc;
    
    # SSL 證書路徑（Let's Encrypt 會自動配置）
    # ssl_certificate /etc/letsencrypt/live/vectorized.cc/fullchain.pem;
    # ssl_certificate_key /etc/letsencrypt/live/vectorized.cc/privkey.pem;
    
    # SSL 安全配置
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-DSS-AES128-GCM-SHA256:kEDH+AESGCM:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA:ECDHE-ECDSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES128-SHA:DHE-DSS-AES128-SHA256:DHE-RSA-AES256-SHA256:DHE-DSS-AES256-SHA:DHE-RSA-AES256-SHA:!aNULL:!eNULL:!EXPORT:!DES:!RC4:!3DES:!MD5:!PSK;
    ssl_prefer_server_ciphers on;
    
    # HSTS
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
    
    # 其他安全標頭
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' https: data: 'unsafe-inline' 'unsafe-eval';" always;
    
    # 根目錄
    root /var/www/pdfmaster;
    index index.html;
    
    # 主要位置配置
    location / {
        try_files $uri $uri/ /index.html;
        
        # 啟用 gzip 壓縮
        gzip on;
        gzip_vary on;
        gzip_min_length 1024;
        gzip_types text/plain text/css text/xml text/javascript application/javascript application/xml+rss application/json;
    }
    
    # 靜態資源緩存
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|pdf|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    # API 反向代理
    location /api/ {
        proxy_pass http://localhost:3000/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        
        # 超時設置
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
    
    # 禁止訪問隱藏檔案
    location ~ /\. {
        deny all;
    }
    
    # 錯誤頁面
    error_page 404 /404.html;
    error_page 500 502 503 504 /50x.html;
    
    # 日誌
    access_log /var/log/nginx/pdfmaster_access.log;
    error_log /var/log/nginx/pdfmaster_error.log;
}
EOF
    
    # 啟用網站配置
    ln -sf $NGINX_CONF /etc/nginx/sites-enabled/
    
    # 測試 Nginx 配置
    nginx -t
    
    # 重新載入 Nginx
    systemctl reload nginx
}

# 配置 SSL 證書
configure_ssl() {
    print_message "正在配置 SSL 證書..."
    
    # 創建 certbot webroot 目錄
    mkdir -p /var/www/certbot
    
    # 獲取 Let's Encrypt SSL 證書
    certbot --nginx -d $DOMAIN -d $WWW_DOMAIN --non-interactive --agree-tos --email $EMAIL --redirect
    
    # 設置自動更新
    print_message "設置 SSL 證書自動更新..."
    
    # 創建更新腳本
    cat > /etc/cron.daily/certbot-renew << 'EOF'
#!/bin/bash
certbot renew --quiet --post-hook "systemctl reload nginx"
EOF
    
    chmod +x /etc/cron.daily/certbot-renew
}

# 配置防火牆
configure_firewall() {
    print_message "正在配置防火牆..."
    
    # 安裝 ufw
    apt install -y ufw
    
    # 配置防火牆規則
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow ssh
    ufw allow 'Nginx Full'
    
    # 啟用防火牆
    echo "y" | ufw enable
}

# 創建更新腳本
create_update_script() {
    print_message "創建更新腳本..."
    
    mkdir -p /root/scripts
    
    cat > /root/scripts/update-pdfmaster.sh << 'EOF'
#!/bin/bash
# PDF Master 更新腳本

APP_DIR="/var/www/pdfmaster"
BACKUP_DIR="/root/backups"
DATE=$(date +%Y%m%d_%H%M%S)

echo "正在更新 PDF Master..."

# 備份當前版本
mkdir -p $BACKUP_DIR
tar -czf $BACKUP_DIR/pdfmaster_before_update_$DATE.tar.gz -C /var/www pdfmaster

# 進入應用程式目錄
cd $APP_DIR

# 保存 .env 檔案
cp .env .env.backup

# 拉取最新代碼
git pull origin main

# 恢復 .env 檔案
cp .env.backup .env

# 設置權限
chown -R www-data:www-data $APP_DIR
chmod -R 755 $APP_DIR

# 重新載入 Nginx
systemctl reload nginx

echo "更新完成！"
EOF
    
    chmod +x /root/scripts/update-pdfmaster.sh
    
    print_message "更新腳本創建完成！使用 /root/scripts/update-pdfmaster.sh 更新專案"
}

# 顯示部署資訊
show_deployment_info() {
    print_message "部署完成！"
    echo ""
    echo "=========================================="
    echo "PDF Master 部署資訊"
    echo "=========================================="
    echo "域名: https://$DOMAIN"
    echo "備用域名: https://$WWW_DOMAIN"
    echo "應用程式目錄: $APP_DIR"
    echo "Git 倉庫: $GIT_REPO"
    echo "分支: $BRANCH"
    echo ""
    echo "管理命令:"
    echo "- 更新專案: /root/scripts/update-pdfmaster.sh"
    echo "- 重啟 Nginx: systemctl restart nginx"
    echo "- 查看日誌: tail -f /var/log/nginx/pdfmaster_*.log"
    echo "- 編輯 .env: nano $APP_DIR/.env"
    echo ""
    echo "Git 操作:"
    echo "- 查看狀態: cd $APP_DIR && git status"
    echo "- 拉取更新: cd $APP_DIR && git pull"
    echo "- 查看日誌: cd $APP_DIR && git log"
    echo "=========================================="
}

# 主函數
main() {
    print_message "開始從 Git 部署 PDF Master 到 vectorized.cc..."
    
    check_root
    update_system
    install_dependencies
    clone_from_git
    create_env_file
    configure_nginx
    configure_ssl
    configure_firewall
    create_update_script
    show_deployment_info
    
    print_message "部署完成！請訪問 https://$DOMAIN 查看您的網站。"
}

# 執行主函數
main 
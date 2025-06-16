#!/bin/bash

# PDF Master 一鍵部署腳本 - Ubuntu 22.04 x64
# 域名: vectorized.shop
# 功能: 自動安裝 Nginx, 配置 SSL, 設置反向代理

set -e  # 遇到錯誤立即退出

# 顏色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 配置變數
DOMAIN="vectorized.shop"
WWW_DOMAIN="www.vectorized.shop"
APP_DIR="/var/www/pdfmaster"
NGINX_CONF="/etc/nginx/sites-available/pdfmaster"
EMAIL="admin@vectorized.shop"  # Let's Encrypt 通知郵箱

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

# 創建應用程式目錄
create_app_directory() {
    print_message "正在創建應用程式目錄..."
    mkdir -p $APP_DIR
    cd $APP_DIR
}

# 部署應用程式檔案
deploy_application() {
    print_message "正在部署應用程式..."
    
    # 如果是從 Git 倉庫部署
    # git clone https://github.com/yourusername/pdfmaster.git .
    
    # 如果是從本地複製（假設腳本和應用程式在同一目錄）
    if [ -f "index.html" ]; then
        cp -r * $APP_DIR/
    else
        print_warning "未找到應用程式檔案，請手動上傳到 $APP_DIR"
    fi
    
    # 設置正確的權限
    chown -R www-data:www-data $APP_DIR
    chmod -R 755 $APP_DIR
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
    server_name vectorized.shop www.vectorized.shop;
    
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
    server_name vectorized.shop www.vectorized.shop;
    
    # SSL 證書路徑（Let's Encrypt 會自動配置）
    # ssl_certificate /etc/letsencrypt/live/vectorized.shop/fullchain.pem;
    # ssl_certificate_key /etc/letsencrypt/live/vectorized.shop/privkey.pem;
    
    # SSL 安全配置
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-DSS-AES128-GCM-SHA256:kEDH+AESGCM:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA:ECDHE-ECDSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES128-SHA:DHE-DSS-AES128-SHA256:DHE-RSA-AES256-SHA256:DHE-DSS-AES256-SHA:DHE-RSA-AES256-SHA:!aNULL:!eNULL:!EXPORT:!DES:!RC4:!3DES:!MD5:!PSK;
    ssl_prefer_server_ciphers on;
    
    # HSTS (強制 HTTPS)
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
    
    # API 反向代理（如果有後端服務）
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

# 創建系統服務（如果需要後端服務）
create_systemd_service() {
    print_message "創建系統服務..."
    
    cat > /etc/systemd/system/pdfmaster-api.service << 'EOF'
[Unit]
Description=PDF Master API Service
After=network.target

[Service]
Type=simple
User=www-data
WorkingDirectory=/var/www/pdfmaster
ExecStart=/usr/bin/node /var/www/pdfmaster/api-server.js
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    
    # 重新載入 systemd
    systemctl daemon-reload
    
    # 啟用並啟動服務（如果存在 api-server.js）
    if [ -f "$APP_DIR/api-server.js" ]; then
        systemctl enable pdfmaster-api
        systemctl start pdfmaster-api
    fi
}

# 優化系統性能
optimize_system() {
    print_message "正在優化系統性能..."
    
    # 調整系統參數
    cat >> /etc/sysctl.conf << 'EOF'

# PDF Master 性能優化
net.core.somaxconn = 65535
net.ipv4.tcp_max_tw_buckets = 1440000
net.ipv4.ip_local_port_range = 1024 65000
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_keepalive_time = 300
net.ipv4.tcp_keepalive_probes = 5
net.ipv4.tcp_keepalive_intvl = 15
EOF
    
    # 應用系統參數
    sysctl -p
}

# 創建備份腳本
create_backup_script() {
    print_message "創建備份腳本..."
    
    mkdir -p /root/scripts
    
    cat > /root/scripts/backup-pdfmaster.sh << 'EOF'
#!/bin/bash
# PDF Master 備份腳本

BACKUP_DIR="/root/backups"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="pdfmaster_backup_$DATE.tar.gz"

mkdir -p $BACKUP_DIR

# 備份應用程式檔案
tar -czf $BACKUP_DIR/$BACKUP_FILE -C /var/www pdfmaster

# 備份 Nginx 配置
cp /etc/nginx/sites-available/pdfmaster $BACKUP_DIR/nginx_config_$DATE

# 保留最近 7 天的備份
find $BACKUP_DIR -name "pdfmaster_backup_*.tar.gz" -mtime +7 -delete

echo "備份完成: $BACKUP_FILE"
EOF
    
    chmod +x /root/scripts/backup-pdfmaster.sh
    
    # 添加到 crontab（每天凌晨 3 點備份）
    (crontab -l 2>/dev/null; echo "0 3 * * * /root/scripts/backup-pdfmaster.sh") | crontab -
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
    echo "Nginx 配置: $NGINX_CONF"
    echo "SSL 證書: Let's Encrypt (自動更新)"
    echo ""
    echo "管理命令:"
    echo "- 重啟 Nginx: systemctl restart nginx"
    echo "- 查看 Nginx 日誌: tail -f /var/log/nginx/pdfmaster_*.log"
    echo "- 更新 SSL 證書: certbot renew"
    echo "- 手動備份: /root/scripts/backup-pdfmaster.sh"
    echo ""
    echo "安全建議:"
    echo "1. 定期更新系統: apt update && apt upgrade"
    echo "2. 監控日誌檔案"
    echo "3. 設置監控告警"
    echo "=========================================="
}

# 主函數
main() {
    print_message "開始部署 PDF Master 到 vectorized.shop..."
    
    check_root
    update_system
    install_dependencies
    create_app_directory
    deploy_application
    configure_nginx
    configure_ssl
    configure_firewall
    create_systemd_service
    optimize_system
    create_backup_script
    show_deployment_info
    
    print_message "部署完成！請訪問 https://$DOMAIN 查看您的網站。"
}

# 執行主函數
main 
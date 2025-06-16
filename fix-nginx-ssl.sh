#!/bin/bash

# 修復 Nginx SSL 配置問題
# 這個腳本會先使用 HTTP 配置，獲取 SSL 證書後再啟用 HTTPS

set -e

# 顏色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== 修復 Nginx SSL 配置 ===${NC}"

# 檢查是否為 root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}錯誤: 此腳本需要 root 權限運行${NC}"
   exit 1
fi

# 詢問域名
read -p "請輸入您的域名 (例如: example.com): " DOMAIN
if [ -z "$DOMAIN" ]; then
    echo -e "${RED}錯誤: 域名不能為空${NC}"
    exit 1
fi

# 備份原始配置
echo "備份原始配置..."
cp /etc/nginx/sites-available/pdfmaster /etc/nginx/sites-available/pdfmaster.backup

# 創建臨時的 HTTP 配置（用於獲取 SSL 證書）
echo "創建臨時 HTTP 配置..."
cat > /etc/nginx/sites-available/pdfmaster-temp << EOF
server {
    listen 80;
    server_name $DOMAIN;
    root /var/www/pdfmaster;
    index index.html;

    location / {
        try_files \$uri \$uri/ =404;
    }

    # Let's Encrypt 驗證路徑
    location /.well-known/acme-challenge/ {
        root /var/www/pdfmaster;
    }
}
EOF

# 啟用臨時配置
echo "啟用臨時配置..."
ln -sf /etc/nginx/sites-available/pdfmaster-temp /etc/nginx/sites-enabled/pdfmaster
rm -f /etc/nginx/sites-enabled/default

# 測試並重啟 Nginx
echo "重啟 Nginx..."
nginx -t
systemctl restart nginx

# 檢查 Nginx 狀態
if systemctl is-active --quiet nginx; then
    echo -e "${GREEN}Nginx 已成功啟動${NC}"
else
    echo -e "${RED}Nginx 啟動失敗${NC}"
    systemctl status nginx
    exit 1
fi

# 安裝 Certbot（如果還沒安裝）
if ! command -v certbot &> /dev/null; then
    echo "安裝 Certbot..."
    apt-get update
    apt-get install -y certbot python3-certbot-nginx
fi

# 獲取 SSL 證書
echo -e "\n${YELLOW}準備獲取 SSL 證書...${NC}"
echo "請確保您的域名已經指向這個服務器的 IP 地址"
read -p "按 Enter 繼續..."

certbot certonly --webroot -w /var/www/pdfmaster -d $DOMAIN --non-interactive --agree-tos --email admin@$DOMAIN

# 檢查證書是否成功獲取
if [ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]; then
    echo -e "${GREEN}SSL 證書獲取成功！${NC}"
    
    # 創建完整的 HTTPS 配置
    echo "創建完整的 HTTPS 配置..."
    cat > /etc/nginx/sites-available/pdfmaster << EOF
# HTTP 重定向到 HTTPS
server {
    listen 80;
    server_name $DOMAIN;
    return 301 https://\$server_name\$request_uri;
}

# HTTPS 配置
server {
    listen 443 ssl http2;
    server_name $DOMAIN;
    root /var/www/pdfmaster;
    index index.html;

    # SSL 證書
    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    
    # SSL 配置
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    
    # 安全標頭
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    
    # Gzip 壓縮
    gzip on;
    gzip_types text/plain text/css text/javascript application/javascript application/json;
    gzip_min_length 1000;
    
    # 靜態文件緩存
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|pdf)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    location / {
        try_files \$uri \$uri/ /index.html;
    }
    
    # API 代理（如果需要）
    location /api/ {
        proxy_pass http://localhost:3000/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF

    # 移除臨時配置，啟用正式配置
    rm -f /etc/nginx/sites-available/pdfmaster-temp
    ln -sf /etc/nginx/sites-available/pdfmaster /etc/nginx/sites-enabled/pdfmaster
    
    # 測試並重啟 Nginx
    nginx -t && systemctl reload nginx
    
    echo -e "${GREEN}=== 配置完成！===${NC}"
    echo -e "您的網站現在可以通過以下地址訪問："
    echo -e "  ${GREEN}https://$DOMAIN${NC}"
    
    # 設置自動續期
    echo "設置 SSL 證書自動續期..."
    (crontab -l 2>/dev/null; echo "0 0,12 * * * certbot renew --quiet --post-hook 'systemctl reload nginx'") | crontab -
    
else
    echo -e "${RED}SSL 證書獲取失敗${NC}"
    echo "請檢查："
    echo "1. 域名是否正確指向服務器 IP"
    echo "2. 防火牆是否開放 80 和 443 端口"
    echo "3. 域名是否可以正常解析"
    exit 1
fi

echo -e "\n${GREEN}所有配置已完成！${NC}" 
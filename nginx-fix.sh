#!/bin/bash

# 修復 Nginx SSL 配置問題

echo "正在修復 Nginx SSL 配置..."

# 1. 先暫時禁用 SSL，只使用 HTTP
cat > /etc/nginx/sites-available/pdfmaster << 'EOF'
# PDF Master Nginx 配置 - 臨時 HTTP 版本

server {
    listen 80;
    listen [::]:80;
    server_name vectorized.cc www.vectorized.cc;
    
    # 根目錄
    root /var/www/pdfmaster;
    index index.html;
    
    # Let's Encrypt 驗證目錄
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }
    
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

# 2. 測試配置
nginx -t

# 3. 重新載入 Nginx
systemctl reload nginx

echo "✅ Nginx 已配置為 HTTP 模式"
echo ""
echo "現在請執行以下命令獲取 SSL 證書："
echo ""
echo "certbot --nginx -d vectorized.cc -d www.vectorized.cc"
echo ""
echo "Certbot 會自動更新 Nginx 配置並啟用 HTTPS。" 
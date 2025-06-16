#!/bin/bash

# 快速修復 Nginx SSL 配置問題

echo "=== 快速修復 Nginx SSL 配置 ==="

# 創建臨時的 HTTP-only 配置
cat > /etc/nginx/sites-available/pdfmaster-temp << 'EOF'
server {
    listen 80;
    server_name _;
    
    root /var/www/pdfmaster;
    index index.html;
    
    location / {
        try_files $uri $uri/ /index.html;
    }
    
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|pdf)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    # API 代理（如果需要）
    location /api {
        proxy_pass http://localhost:3001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}
EOF

# 備份原配置
if [ -f /etc/nginx/sites-enabled/pdfmaster ]; then
    mv /etc/nginx/sites-enabled/pdfmaster /etc/nginx/sites-enabled/pdfmaster.bak
fi

# 啟用臨時配置
ln -sf /etc/nginx/sites-available/pdfmaster-temp /etc/nginx/sites-enabled/pdfmaster

# 測試配置
if nginx -t; then
    echo "Nginx 配置測試通過"
    systemctl restart nginx
    echo "Nginx 已重啟"
    
    # 檢查服務狀態
    if systemctl is-active --quiet nginx; then
        echo "✅ Nginx 正在運行！"
        echo ""
        echo "網站現在可以通過 HTTP 訪問了。"
        echo ""
        echo "如果您有域名，可以運行以下命令獲取 SSL 證書："
        echo "sudo certbot --nginx -d your-domain.com"
    else
        echo "❌ Nginx 啟動失敗"
        systemctl status nginx
    fi
else
    echo "❌ Nginx 配置測試失敗"
    nginx -t
fi 
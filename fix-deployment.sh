#!/bin/bash

echo "=== 修復 PDF Master 部署問題 ==="

# 1. 檢查並移除重複的 Nginx 配置
echo "1. 檢查 Nginx 配置..."
echo "現有的 Nginx 站點配置："
ls -la /etc/nginx/sites-enabled/

# 移除可能的重複配置
if [ -f "/etc/nginx/sites-enabled/default" ]; then
    echo "移除預設站點..."
    rm /etc/nginx/sites-enabled/default
fi

# 2. 檢查防火牆設置
echo ""
echo "2. 檢查防火牆..."
ufw status

# 確保 HTTP 和 HTTPS 端口開放
echo "開放必要端口..."
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 22/tcp
echo "y" | ufw enable

# 3. 檢查域名解析
echo ""
echo "3. 檢查域名解析..."
echo "vectorized.cc 解析到："
dig +short vectorized.cc
echo "www.vectorized.cc 解析到："
dig +short www.vectorized.cc
echo "服務器 IP："
curl -s ifconfig.me
echo ""

# 4. 創建簡化的 Nginx 配置
echo ""
echo "4. 創建新的 Nginx 配置..."
cat > /etc/nginx/sites-available/pdfmaster << 'EOF'
server {
    listen 80;
    listen [::]:80;
    server_name vectorized.cc www.vectorized.cc;
    
    root /var/www/pdfmaster;
    index index.html;
    
    # Let's Encrypt 驗證
    location /.well-known/acme-challenge/ {
        allow all;
        root /var/www/certbot;
    }
    
    location / {
        try_files $uri $uri/ /index.html;
    }
    
    # API 代理
    location /api/ {
        proxy_pass http://localhost:3000/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

# 5. 創建驗證目錄
echo "創建驗證目錄..."
mkdir -p /var/www/certbot
mkdir -p /var/www/pdfmaster
chown -R www-data:www-data /var/www/certbot
chown -R www-data:www-data /var/www/pdfmaster

# 6. 測試 Nginx 配置
echo ""
echo "測試 Nginx 配置..."
nginx -t

# 7. 重啟 Nginx
echo "重啟 Nginx..."
systemctl restart nginx

# 8. 測試 HTTP 訪問
echo ""
echo "測試 HTTP 訪問..."
curl -I http://vectorized.cc

echo ""
echo "=== 修復完成 ==="
echo ""
echo "現在請執行以下命令獲取 SSL 證書："
echo "certbot --nginx -d vectorized.cc -d www.vectorized.cc"
echo ""
echo "如果還是失敗，請檢查："
echo "1. 域名是否正確指向服務器 IP"
echo "2. 防火牆是否開放 80 和 443 端口"
echo "3. 是否有其他程序佔用 80 端口" 
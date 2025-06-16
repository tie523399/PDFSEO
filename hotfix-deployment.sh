#!/bin/bash

# PDF Master 部署熱修復腳本
# 用於修復一鍵部署後的常見問題

echo "======================================"
echo "PDF Master 部署問題修復"
echo "======================================"

# 1. 修復 Nginx 重複配置
echo "1. 修復 Nginx 配置..."
if [ -f "/etc/nginx/sites-enabled/default" ]; then
    echo "   移除預設站點..."
    rm -f /etc/nginx/sites-enabled/default
fi

# 2. 修復防火牆設置
echo "2. 修復防火牆..."
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 22/tcp
ufw allow 'Nginx Full'
echo "   防火牆端口已開放: 22, 80, 443"

# 3. 創建必要目錄
echo "3. 創建必要目錄..."
mkdir -p /var/www/certbot/.well-known/acme-challenge/
mkdir -p /var/www/pdfmaster
chown -R www-data:www-data /var/www/certbot
chown -R www-data:www-data /var/www/pdfmaster

# 4. 重啟服務
echo "4. 重啟服務..."
systemctl restart nginx

# 5. 測試配置
echo "5. 測試配置..."
nginx -t

# 6. 顯示狀態
echo ""
echo "======================================"
echo "修復完成！當前狀態："
echo "======================================"
echo "防火牆狀態："
ufw status numbered
echo ""
echo "Nginx 站點："
ls -la /etc/nginx/sites-enabled/
echo ""
echo "服務狀態："
systemctl status nginx --no-pager

echo ""
echo "======================================"
echo "下一步："
echo "======================================"
echo "1. 確認域名解析正確"
echo "2. 執行以下命令獲取 SSL 證書："
echo ""
echo "certbot --nginx -d vectorized.cc -d www.vectorized.cc"
echo ""
echo "======================================" 
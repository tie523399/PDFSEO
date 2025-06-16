#!/bin/bash

# 修復 Git 所有權問題並繼續部署

APP_DIR="/var/www/pdfmaster"

echo "修復 Git 安全目錄問題..."
git config --global --add safe.directory $APP_DIR

echo "繼續部署..."
cd $APP_DIR

# 拉取最新代碼
git pull origin main

# 設置權限
chown -R www-data:www-data $APP_DIR
chmod -R 755 $APP_DIR

echo "修復完成！"
echo ""
echo "現在可以重新運行部署腳本："
echo "sudo bash vectorized-deploy.sh" 
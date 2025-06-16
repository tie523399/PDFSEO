#!/bin/bash

# 清理並重新部署 Vectorized.cc

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}=== 清理並重新部署 Vectorized.cc ===${NC}"

# 備份重要文件（如果需要）
if [ -f "/var/www/pdfmaster/.env" ]; then
    echo "備份 .env 文件..."
    cp /var/www/pdfmaster/.env /tmp/pdfmaster-env-backup
fi

# 方法1：強制重置到遠端版本
echo -e "${YELLOW}重置到最新版本...${NC}"
cd /var/www/pdfmaster

# 添加安全目錄
git config --global --add safe.directory /var/www/pdfmaster

# 儲存或丟棄本地更改
echo "丟棄本地更改..."
git reset --hard HEAD
git clean -fd

# 拉取最新代碼
echo "拉取最新代碼..."
git fetch origin main
git reset --hard origin/main

# 恢復備份文件
if [ -f "/tmp/pdfmaster-env-backup" ]; then
    echo "恢復 .env 文件..."
    cp /tmp/pdfmaster-env-backup /var/www/pdfmaster/.env
fi

# 設置權限
chown -R www-data:www-data /var/www/pdfmaster
chmod -R 755 /var/www/pdfmaster

echo -e "${GREEN}清理完成！${NC}"
echo ""
echo "現在運行部署腳本："
echo "cd /var/www/pdfmaster && sudo bash vectorized-deploy.sh" 
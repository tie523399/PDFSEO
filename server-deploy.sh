#!/bin/bash

# PDF Master 服務器端一鍵部署腳本
# 使用方法: 
# 1. 將此腳本複製到服務器
# 2. chmod +x server-deploy.sh
# 3. ./server-deploy.sh

echo "======================================"
echo "PDF Master 一鍵部署腳本"
echo "域名: vectorized.cc"
echo "======================================"
echo ""
echo "此腳本將自動："
echo "1. 從 GitHub 下載專案"
echo "2. 安裝所需軟體"
echo "3. 配置 Nginx 和 SSL"
echo "4. 創建 .env 檔案"
echo ""
read -p "確定要繼續嗎？(y/n) " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "部署已取消"
    exit 1
fi

# 下載並執行部署腳本
echo "正在下載部署腳本..."
wget -O deploy-from-git.sh https://raw.githubusercontent.com/tie523399/PDFSEO/main/deploy-from-git.sh

# 設置執行權限
chmod +x deploy-from-git.sh

# 執行部署
./deploy-from-git.sh 
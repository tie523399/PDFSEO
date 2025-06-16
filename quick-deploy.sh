#!/bin/bash

# PDF Master 快速部署腳本
# 使用方法: bash quick-deploy.sh

# 設定變數
DOMAIN="vectorized.shop"
SERVER_IP="YOUR_SERVER_IP"  # 請替換為您的伺服器 IP
SERVER_USER="root"          # SSH 用戶名

echo "======================================"
echo "PDF Master 快速部署腳本"
echo "域名: $DOMAIN"
echo "======================================"

# 步驟 1: 打包本地檔案
echo "[1/4] 正在打包應用程式檔案..."
tar -czf pdfmaster.tar.gz \
    index.html \
    README.md \
    robots.txt \
    sitemap.xml \
    seo-config.json \
    api-mock.js \
    deploy.sh

echo "✓ 打包完成"

# 步驟 2: 上傳檔案到伺服器
echo "[2/4] 正在上傳檔案到伺服器..."
echo "請輸入伺服器 IP 地址:"
read SERVER_IP

scp pdfmaster.tar.gz deploy.sh $SERVER_USER@$SERVER_IP:/root/

echo "✓ 上傳完成"

# 步驟 3: 連接到伺服器並執行部署
echo "[3/4] 正在連接到伺服器並執行部署..."

ssh $SERVER_USER@$SERVER_IP << 'ENDSSH'
cd /root
tar -xzf pdfmaster.tar.gz
chmod +x deploy.sh
./deploy.sh
ENDSSH

echo "✓ 部署完成"

# 步驟 4: 清理本地臨時檔案
echo "[4/4] 清理臨時檔案..."
rm -f pdfmaster.tar.gz

echo ""
echo "======================================"
echo "部署成功！"
echo "請訪問: https://$DOMAIN"
echo "======================================" 
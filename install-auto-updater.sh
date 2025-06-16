#!/bin/bash

# 安裝 PDF Master 自動更新系統

set -e

# 顏色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== 安裝 PDF Master 自動更新系統 ===${NC}"

# 檢查是否為 root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}錯誤: 此腳本需要 root 權限運行${NC}"
   exit 1
fi

# 詢問 Git 倉庫地址
read -p "請輸入您的 Git 倉庫地址 (例如: https://github.com/username/repo.git): " GIT_REPO
if [ -z "$GIT_REPO" ]; then
    echo -e "${RED}錯誤: Git 倉庫地址不能為空${NC}"
    exit 1
fi

# 詢問分支名稱
read -p "請輸入要追蹤的分支名稱 (預設: main): " BRANCH
BRANCH=${BRANCH:-main}

# 詢問專案目錄
read -p "請輸入專案部署目錄 (預設: /var/www/pdfmaster): " REPO_DIR
REPO_DIR=${REPO_DIR:-/var/www/pdfmaster}

# 詢問域名
read -p "請輸入您的域名 (如果沒有域名，請直接按 Enter): " DOMAIN
DOMAIN=${DOMAIN:-_}

# 詢問是否配置 Telegram 通知
read -p "是否要配置 Telegram 通知? (y/n): " SETUP_TELEGRAM
if [ "$SETUP_TELEGRAM" = "y" ]; then
    read -p "請輸入 Telegram Bot Token: " TELEGRAM_BOT_TOKEN
    read -p "請輸入 Telegram Chat ID: " TELEGRAM_CHAT_ID
fi

# 詢問更新頻率
echo -e "\n${YELLOW}選擇更新檢查頻率:${NC}"
echo "1) 每 15 分鐘"
echo "2) 每 30 分鐘 (預設)"
echo "3) 每小時"
echo "4) 每 6 小時"
echo "5) 每天"
read -p "請選擇 (1-5): " UPDATE_FREQ

case $UPDATE_FREQ in
    1) TIMER_SCHEDULE="*:0/15" ;;
    3) TIMER_SCHEDULE="*:0" ;;
    4) TIMER_SCHEDULE="0/6:0" ;;
    5) TIMER_SCHEDULE="daily" ;;
    *) TIMER_SCHEDULE="*:0/30" ;;
esac

echo -e "\n${GREEN}開始安裝...${NC}"

# 1. 複製自動更新腳本
echo "1. 安裝自動更新腳本..."
cp auto-update.sh /usr/local/bin/
chmod +x /usr/local/bin/auto-update.sh

# 2. 更新腳本中的配置
sed -i "s|^GIT_REPO=.*|GIT_REPO=\"$GIT_REPO\"|" /usr/local/bin/auto-update.sh
sed -i "s|^BRANCH=.*|BRANCH=\"$BRANCH\"|" /usr/local/bin/auto-update.sh
sed -i "s|^REPO_DIR=.*|REPO_DIR=\"$REPO_DIR\"|" /usr/local/bin/auto-update.sh
sed -i "s|^DOMAIN=.*|DOMAIN=\"$DOMAIN\"|" /usr/local/bin/auto-update.sh

# 3. 複製 systemd 服務文件
echo "2. 安裝 systemd 服務..."
cp pdfmaster-updater.service /etc/systemd/system/

# 4. 更新服務文件中的環境變數
if [ "$SETUP_TELEGRAM" = "y" ]; then
    sed -i "s|Environment=\"TELEGRAM_BOT_TOKEN=.*\"|Environment=\"TELEGRAM_BOT_TOKEN=$TELEGRAM_BOT_TOKEN\"|" /etc/systemd/system/pdfmaster-updater.service
    sed -i "s|Environment=\"TELEGRAM_CHAT_ID=.*\"|Environment=\"TELEGRAM_CHAT_ID=$TELEGRAM_CHAT_ID\"|" /etc/systemd/system/pdfmaster-updater.service
else
    # 移除 Telegram 環境變數行
    sed -i '/Environment="TELEGRAM_BOT_TOKEN=/d' /etc/systemd/system/pdfmaster-updater.service
    sed -i '/Environment="TELEGRAM_CHAT_ID=/d' /etc/systemd/system/pdfmaster-updater.service
fi

# 5. 複製並配置 timer
echo "3. 安裝 systemd timer..."
cp pdfmaster-updater.timer /etc/systemd/system/
sed -i "s|OnCalendar=.*|OnCalendar=$TIMER_SCHEDULE|" /etc/systemd/system/pdfmaster-updater.timer

# 6. 創建必要的目錄
echo "4. 創建必要的目錄..."
mkdir -p /var/log
mkdir -p /var/backups/pdfmaster

# 7. 重新載入 systemd
echo "5. 啟動服務..."
systemctl daemon-reload
systemctl enable pdfmaster-updater.timer
systemctl start pdfmaster-updater.timer

# 8. 顯示狀態
echo -e "\n${GREEN}=== 安裝完成！===${NC}"
echo -e "\n${YELLOW}服務狀態:${NC}"
systemctl status pdfmaster-updater.timer --no-pager

echo -e "\n${YELLOW}有用的命令:${NC}"
echo "查看更新日誌: tail -f /var/log/pdfmaster-update.log"
echo "手動執行更新: systemctl start pdfmaster-updater.service"
echo "查看計時器狀態: systemctl status pdfmaster-updater.timer"
echo "查看下次執行時間: systemctl list-timers pdfmaster-updater.timer"
echo "停止自動更新: systemctl stop pdfmaster-updater.timer"
echo "禁用自動更新: systemctl disable pdfmaster-updater.timer"

echo -e "\n${GREEN}自動更新系統已成功安裝並啟動！${NC}" 
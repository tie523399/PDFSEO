#!/bin/bash

# PDF Master 自動更新腳本
# 用於從 Git 倉庫自動拉取更新並重新部署

# 設定變數
REPO_DIR="/var/www/pdfmaster"
GIT_REPO="https://github.com/tie523399/PDFSEO.git"  # 固定 Git 倉庫
BRANCH="main"
LOG_FILE="/var/log/pdfmaster-update.log"
BACKUP_DIR="/var/backups/pdfmaster"
NGINX_CONFIG="/etc/nginx/sites-available/pdfmaster"
DOMAIN="vectorized.cc"  # 固定域名

# Telegram 配置（固定）
TELEGRAM_BOT_TOKEN="7002177842:AAE7cXJpmqXKmZAh19aef2P4dfnxW0GVjZs"
TELEGRAM_CHAT_ID="7341258916"

# 顏色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 記錄函數
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# 錯誤處理
error_exit() {
    echo -e "${RED}錯誤: $1${NC}" | tee -a "$LOG_FILE"
    exit 1
}

# 檢查是否以 root 權限運行
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error_exit "此腳本需要 root 權限運行"
    fi
}

# 創建必要的目錄
create_directories() {
    mkdir -p "$BACKUP_DIR"
    mkdir -p "$(dirname "$LOG_FILE")"
}

# 備份當前版本
backup_current() {
    log "開始備份當前版本..."
    if [ -d "$REPO_DIR" ]; then
        BACKUP_NAME="backup_$(date +%Y%m%d_%H%M%S)"
        cp -r "$REPO_DIR" "$BACKUP_DIR/$BACKUP_NAME"
        
        # 只保留最近 5 個備份
        cd "$BACKUP_DIR"
        ls -t | tail -n +6 | xargs -r rm -rf
        
        log "備份完成: $BACKUP_DIR/$BACKUP_NAME"
    fi
}

# 檢查 Git 是否有更新
check_updates() {
    cd "$REPO_DIR" || error_exit "無法進入專案目錄"
    
    # 獲取遠端更新
    git fetch origin "$BRANCH" &>/dev/null
    
    # 比較本地和遠端
    LOCAL=$(git rev-parse HEAD)
    REMOTE=$(git rev-parse origin/"$BRANCH")
    
    if [ "$LOCAL" = "$REMOTE" ]; then
        log "沒有新的更新"
        return 1
    else
        log "發現新的更新"
        return 0
    fi
}

# 拉取更新
pull_updates() {
    log "開始拉取更新..."
    
    cd "$REPO_DIR" || error_exit "無法進入專案目錄"
    
    # 儲存本地修改（如果有）
    if ! git diff --quiet; then
        log "發現本地修改，暫存中..."
        git stash push -m "Auto stash before update $(date +%Y%m%d_%H%M%S)"
    fi
    
    # 拉取更新
    if git pull origin "$BRANCH"; then
        log "更新拉取成功"
        
        # 獲取更新內容
        LAST_COMMIT=$(git log -1 --pretty=format:"%h - %s (%cr) <%an>")
        log "最新提交: $LAST_COMMIT"
    else
        error_exit "拉取更新失敗"
    fi
}

# 安裝依賴（如果需要）
install_dependencies() {
    # 檢查是否有 package.json
    if [ -f "$REPO_DIR/package.json" ]; then
        log "發現 package.json，安裝 Node.js 依賴..."
        cd "$REPO_DIR"
        npm install --production
    fi
    
    # 檢查是否有 requirements.txt
    if [ -f "$REPO_DIR/requirements.txt" ]; then
        log "發現 requirements.txt，安裝 Python 依賴..."
        pip3 install -r "$REPO_DIR/requirements.txt"
    fi
}

# 檢查並修復 SSL 配置
check_and_fix_ssl() {
    log "檢查 SSL 配置..."
    
    # 確保主配置文件存在
    if [ ! -f "/etc/nginx/sites-available/pdfmaster" ]; then
        log "創建主 Nginx 配置..."
        cat > /etc/nginx/sites-available/pdfmaster << 'EOF'
# PDF Master 主配置
server {
    listen 80;
    server_name _;
    
    root /var/www/pdfmaster;
    index index.html;
    
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
        try_files $uri =404;
    }
    
    location / {
        try_files $uri $uri/ /index.html;
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header X-XSS-Protection "1; mode=block" always;
    }
    
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|pdf|woff|woff2|ttf|svg)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        access_log off;
    }
    
    location /api {
        proxy_pass http://localhost:3001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
    
    location /health {
        access_log off;
        return 200 "OK\n";
        add_header Content-Type text/plain;
    }
}

# 條件包含 SSL 配置
include /etc/nginx/sites-available/pdfmaster-ssl-active.conf;
EOF
        ln -sf /etc/nginx/sites-available/pdfmaster /etc/nginx/sites-enabled/pdfmaster
    fi
    
    # 檢查是否有 SSL 證書
    if [ -n "$DOMAIN" ] && [ "$DOMAIN" != "_" ] && [ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]; then
        log "SSL 證書存在，啟用 HTTPS 配置"
        
        # 創建 SSL 配置
        cat > /etc/nginx/sites-available/pdfmaster-ssl-active.conf << EOF
# SSL 配置 - 自動生成
server {
    listen 443 ssl http2;
    server_name $DOMAIN;
    
    root /var/www/pdfmaster;
    index index.html;
    
    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256;
    ssl_prefer_server_ciphers off;
    
    add_header Strict-Transport-Security "max-age=31536000" always;
    
    location / {
        try_files \$uri \$uri/ /index.html;
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header X-XSS-Protection "1; mode=block" always;
    }
    
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|pdf|woff|woff2|ttf|svg)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        access_log off;
    }
    
    location /api {
        proxy_pass http://localhost:3001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}

# HTTP 到 HTTPS 重定向
server {
    listen 80;
    server_name $DOMAIN;
    return 301 https://\$server_name\$request_uri;
}
EOF
    else
        log "SSL 證書不存在或未配置域名，使用 HTTP only 模式"
        # 創建空的 SSL 配置文件以避免 include 錯誤
        echo "# SSL 未啟用" > /etc/nginx/sites-available/pdfmaster-ssl-active.conf
        
        # 如果有域名但沒有證書，嘗試獲取
        if [ -n "$DOMAIN" ] && [ "$DOMAIN" != "_" ]; then
            log "嘗試為 $DOMAIN 獲取 SSL 證書..."
            mkdir -p /var/www/certbot
            if certbot certonly --webroot -w /var/www/certbot -d "$DOMAIN" --non-interactive --agree-tos --email admin@$DOMAIN; then
                log "SSL 證書獲取成功，重新配置..."
                check_and_fix_ssl  # 遞歸調用以應用 SSL 配置
            else
                log "SSL 證書獲取失敗，繼續使用 HTTP"
            fi
        fi
    fi
}

# 重啟服務
restart_services() {
    log "重啟服務..."
    
    # 先檢查和修復 SSL
    check_and_fix_ssl
    
    # 測試 Nginx 配置
    if nginx -t &>/dev/null; then
        systemctl reload nginx
        log "Nginx 重新載入成功"
    else
        # 如果還是失敗，嘗試使用臨時配置
        log "Nginx 配置測試失敗，嘗試修復..."
        check_and_fix_ssl
    fi
    
    # 如果有 Node.js 應用
    if systemctl is-active --quiet pdfmaster-api; then
        systemctl restart pdfmaster-api
        log "API 服務重啟成功"
    fi
    
    # 清除快取（如果使用 Redis）
    if command -v redis-cli &> /dev/null; then
        redis-cli FLUSHDB &>/dev/null
        log "Redis 快取已清除"
    fi
}

# 健康檢查
health_check() {
    log "執行健康檢查..."
    
    # 檢查網站是否可訪問
    if curl -s -o /dev/null -w "%{http_code}" http://localhost | grep -q "200"; then
        log "網站健康檢查通過"
        return 0
    else
        log "警告: 網站健康檢查失敗"
        return 1
    fi
}

# 回滾功能
rollback() {
    log "開始回滾到上一個版本..."
    
    # 找到最新的備份
    LATEST_BACKUP=$(ls -t "$BACKUP_DIR" | head -1)
    
    if [ -z "$LATEST_BACKUP" ]; then
        error_exit "沒有找到備份，無法回滾"
    fi
    
    # 執行回滾
    rm -rf "$REPO_DIR"
    cp -r "$BACKUP_DIR/$LATEST_BACKUP" "$REPO_DIR"
    
    restart_services
    log "回滾完成"
}

# 發送通知（可選）
send_notification() {
    local status=$1
    local message=$2
    
    # 如果安裝了 mail 命令
    if command -v mail &> /dev/null; then
        echo "$message" | mail -s "PDF Master 更新通知 - $status" admin@example.com
    fi
    
    # 如果配置了 Telegram Bot
    if [ -n "$TELEGRAM_BOT_TOKEN" ] && [ -n "$TELEGRAM_CHAT_ID" ]; then
        curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
            -d "chat_id=$TELEGRAM_CHAT_ID" \
            -d "text=PDF Master 更新通知 - $status: $message" &>/dev/null
    fi
}

# 主函數
main() {
    log "========== 開始自動更新流程 =========="
    
    # 檢查權限
    check_root
    
    # 創建必要目錄
    create_directories
    
    # 檢查專案目錄是否存在
    if [ ! -d "$REPO_DIR" ]; then
        log "專案目錄不存在，執行初始克隆..."
        git clone -b "$BRANCH" "$GIT_REPO" "$REPO_DIR" || error_exit "克隆倉庫失敗"
    fi
    
    # 檢查更新
    if check_updates; then
        # 備份當前版本
        backup_current
        
        # 拉取更新
        pull_updates
        
        # 安裝依賴
        install_dependencies
        
        # 重啟服務
        restart_services
        
        # 健康檢查
        if health_check; then
            log "更新成功完成！"
            send_notification "成功" "PDF Master 已成功更新到最新版本"
        else
            log "更新後健康檢查失敗，執行回滾..."
            rollback
            send_notification "失敗" "PDF Master 更新失敗，已回滾到上一版本"
        fi
    else
        log "當前已是最新版本"
    fi
    
    log "========== 更新流程結束 =========="
}

# 執行主函數
main 
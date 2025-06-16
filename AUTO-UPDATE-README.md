# PDF Master 自動更新系統

這個自動更新系統可以讓您的 Ubuntu 服務器自動從 Git 倉庫拉取最新的代碼並部署。

## 功能特點

- 🔄 **自動檢查更新** - 定期檢查 Git 倉庫是否有新的提交
- 📦 **自動備份** - 更新前自動備份當前版本
- 🚀 **自動部署** - 拉取代碼後自動重啟服務
- 🏥 **健康檢查** - 更新後自動檢查網站是否正常
- ↩️ **自動回滾** - 如果更新失敗，自動回滾到上一版本
- 📧 **通知功能** - 支援 Email 和 Telegram 通知
- 📝 **詳細日誌** - 記錄所有操作步驟

## 安裝步驟

### 1. 準備工作

確保您的服務器已安裝：
- Git
- Nginx
- Node.js (如果有 API 服務)
- curl

```bash
sudo apt update
sudo apt install -y git nginx curl
```

### 2. 下載安裝腳本

```bash
# 下載所有必要文件
wget https://raw.githubusercontent.com/yourusername/pdfmaster/main/auto-update.sh
wget https://raw.githubusercontent.com/yourusername/pdfmaster/main/pdfmaster-updater.service
wget https://raw.githubusercontent.com/yourusername/pdfmaster/main/pdfmaster-updater.timer
wget https://raw.githubusercontent.com/yourusername/pdfmaster/main/install-auto-updater.sh

# 給安裝腳本執行權限
chmod +x install-auto-updater.sh
```

### 3. 運行安裝腳本

```bash
sudo ./install-auto-updater.sh
```

安裝過程中會詢問：
- Git 倉庫地址
- 分支名稱（預設 main）
- 專案部署目錄（預設 /var/www/pdfmaster）
- 是否配置 Telegram 通知
- 更新檢查頻率

### 4. 手動安裝（可選）

如果您想手動安裝：

```bash
# 1. 複製腳本
sudo cp auto-update.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/auto-update.sh

# 2. 編輯配置
sudo nano /usr/local/bin/auto-update.sh
# 修改 GIT_REPO, BRANCH, REPO_DIR 等變數

# 3. 安裝 systemd 服務
sudo cp pdfmaster-updater.service /etc/systemd/system/
sudo cp pdfmaster-updater.timer /etc/systemd/system/

# 4. 啟動服務
sudo systemctl daemon-reload
sudo systemctl enable pdfmaster-updater.timer
sudo systemctl start pdfmaster-updater.timer
```

## 配置說明

### 主要配置項（在 auto-update.sh 中）

```bash
REPO_DIR="/var/www/pdfmaster"          # 專案目錄
GIT_REPO="https://github.com/..."      # Git 倉庫地址
BRANCH="main"                          # 分支名稱
LOG_FILE="/var/log/pdfmaster-update.log"  # 日誌文件
BACKUP_DIR="/var/backups/pdfmaster"    # 備份目錄
```

### 更新頻率配置

編輯 `/etc/systemd/system/pdfmaster-updater.timer`：

```ini
[Timer]
OnCalendar=*:0/30  # 每 30 分鐘
# 其他選項：
# OnCalendar=*:0/15     # 每 15 分鐘
# OnCalendar=hourly     # 每小時
# OnCalendar=daily      # 每天
# OnCalendar=weekly     # 每週
```

### Telegram 通知配置

編輯 `/etc/systemd/system/pdfmaster-updater.service`：

```ini
Environment="TELEGRAM_BOT_TOKEN=your_bot_token"
Environment="TELEGRAM_CHAT_ID=your_chat_id"
```

## 使用方法

### 查看狀態

```bash
# 查看計時器狀態
sudo systemctl status pdfmaster-updater.timer

# 查看下次執行時間
sudo systemctl list-timers pdfmaster-updater.timer

# 查看更新日誌
sudo tail -f /var/log/pdfmaster-update.log
```

### 手動執行更新

```bash
# 立即執行一次更新
sudo systemctl start pdfmaster-updater.service

# 或直接運行腳本
sudo /usr/local/bin/auto-update.sh
```

### 管理服務

```bash
# 停止自動更新
sudo systemctl stop pdfmaster-updater.timer

# 禁用自動更新
sudo systemctl disable pdfmaster-updater.timer

# 重新啟用
sudo systemctl enable pdfmaster-updater.timer
sudo systemctl start pdfmaster-updater.timer
```

## 工作流程

1. **檢查更新** - 使用 `git fetch` 檢查遠端是否有新提交
2. **備份當前版本** - 複製當前代碼到備份目錄
3. **拉取更新** - 使用 `git pull` 獲取最新代碼
4. **安裝依賴** - 如果有 package.json 或 requirements.txt，自動安裝
5. **重啟服務** - 重新載入 Nginx，重啟 API 服務
6. **健康檢查** - 檢查網站是否可以正常訪問
7. **通知** - 發送更新結果通知

## 故障排除

### 查看日誌

```bash
# 查看更新日誌
sudo tail -f /var/log/pdfmaster-update.log

# 查看 systemd 日誌
sudo journalctl -u pdfmaster-updater.service -f
```

### 常見問題

1. **權限問題**
   ```bash
   # 確保腳本有執行權限
   sudo chmod +x /usr/local/bin/auto-update.sh
   
   # 確保目錄權限正確
   sudo chown -R www-data:www-data /var/www/pdfmaster
   ```

2. **Git 認證問題**
   - 使用 HTTPS URL 並配置認證
   - 或使用 SSH 並配置密鑰

3. **服務無法啟動**
   ```bash
   # 檢查服務配置
   sudo systemctl status pdfmaster-updater.service
   sudo journalctl -xe
   ```

## 安全建議

1. **使用專用部署密鑰** - 不要使用個人 Git 賬號
2. **限制權限** - 只給予必要的文件系統權限
3. **監控日誌** - 定期檢查更新日誌
4. **測試環境** - 先在測試環境驗證更新
5. **備份策略** - 定期備份到外部存儲

## 進階配置

### 自定義健康檢查

編輯 `auto-update.sh` 中的 `health_check` 函數：

```bash
health_check() {
    # 檢查多個端點
    endpoints=("/api/health" "/admin" "/")
    for endpoint in "${endpoints[@]}"; do
        if ! curl -s -o /dev/null -w "%{http_code}" "http://localhost$endpoint" | grep -q "200"; then
            return 1
        fi
    done
    return 0
}
```

### 多環境支援

```bash
# 根據分支部署到不同環境
case $BRANCH in
    "main")
        REPO_DIR="/var/www/pdfmaster-prod"
        ;;
    "develop")
        REPO_DIR="/var/www/pdfmaster-dev"
        ;;
esac
```

## 支援

如有問題，請查看：
- 更新日誌：`/var/log/pdfmaster-update.log`
- 系統日誌：`journalctl -u pdfmaster-updater.service`
- Git 倉庫 Issues 
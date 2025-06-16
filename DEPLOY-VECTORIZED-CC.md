# 部署 PDF Master 到 vectorized.cc

## 快速部署步驟

### 1. 準備工作
- 確保您有 Ubuntu 22.04 x64 服務器
- 確保域名 `vectorized.cc` 和 `www.vectorized.cc` 已指向服務器 IP
- 確保有 root 權限的 SSH 訪問

### 2. 部署方式選擇

#### 方式一：直接在服務器上部署（推薦）

SSH 連接到服務器後執行：
```bash
# 下載一鍵部署腳本
wget https://raw.githubusercontent.com/tie523399/PDFSEO/main/server-deploy.sh

# 設置執行權限
chmod +x server-deploy.sh

# 執行部署
./server-deploy.sh
```

或者使用一行命令：
```bash
curl -sSL https://raw.githubusercontent.com/tie523399/PDFSEO/main/server-deploy.sh | bash
```

#### 方式二：從本地上傳部署

在本地執行：
```bash
chmod +x quick-deploy.sh
./quick-deploy.sh
```

腳本會提示您輸入服務器 IP，然後自動完成所有部署步驟。

### 3. 部署內容

部署腳本會自動完成以下工作：

#### 系統配置
- ✅ 更新系統套件
- ✅ 安裝 Nginx、Certbot、Node.js
- ✅ 配置防火牆 (UFW)
- ✅ 優化系統性能

#### 網站配置
- ✅ 部署應用程式到 `/var/www/pdfmaster`
- ✅ 配置 Nginx 虛擬主機
- ✅ 設置 SSL 證書 (Let's Encrypt)
- ✅ 配置 HTTPS 重定向
- ✅ 設置安全標頭 (HSTS, CSP, etc.)

#### 反向代理
- ✅ API 路徑 `/api/` → `http://localhost:3000/`
- ✅ 支援 WebSocket
- ✅ 設置適當的代理標頭

#### 自動化
- ✅ SSL 證書自動更新
- ✅ 每日自動備份
- ✅ 日誌輪轉

### 4. 環境變數配置

部署過程中會提示您輸入：
- 服務器 IP 地址
- Telegram Bot Token（可選）
- Telegram 管理員 ID（可選）

生成的 `.env` 檔案位於：`/var/www/pdfmaster/.env`

### 5. 部署後檢查

```bash
# SSH 連接到服務器
ssh root@YOUR_SERVER_IP

# 檢查服務狀態
systemctl status nginx

# 查看網站
curl https://vectorized.cc

# 查看日誌
tail -f /var/log/nginx/pdfmaster_access.log
```

### 6. Telegram Bot 設置

如果您要使用 Telegram Bot：

1. 在 Telegram 找 @BotFather
2. 創建新 Bot：`/newbot`
3. 獲取 Token
4. 編輯 `.env` 檔案：
   ```bash
   nano /var/www/pdfmaster/.env
   ```
5. 填入您的 Bot Token 和管理員 ID

### 7. 維護命令

```bash
# 重啟 Nginx
systemctl restart nginx

# 更新 SSL 證書
certbot renew

# 手動備份
/root/scripts/backup-pdfmaster.sh

# 查看 .env 檔案
cat /var/www/pdfmaster/.env

# 編輯 .env 檔案
nano /var/www/pdfmaster/.env
```

### 8. 故障排除

#### 無法訪問網站
```bash
# 檢查 Nginx 配置
nginx -t

# 檢查防火牆
ufw status

# 檢查 DNS
nslookup vectorized.cc
```

#### SSL 證書問題
```bash
# 檢查證書狀態
certbot certificates

# 手動更新證書
certbot renew --force-renewal
```

#### 502 Bad Gateway
```bash
# 檢查 API 服務（如果有）
systemctl status pdfmaster-api

# 查看錯誤日誌
tail -f /var/log/nginx/pdfmaster_error.log
```

### 9. 安全建議

1. **定期更新系統**
   ```bash
   apt update && apt upgrade -y
   ```

2. **設置 SSH 金鑰認證**
   ```bash
   ssh-copy-id root@vectorized.cc
   ```

3. **監控日誌**
   ```bash
   # 安裝日誌監控工具
   apt install logwatch
   ```

4. **設置 Fail2ban**
   ```bash
   apt install fail2ban
   ```

### 10. 完成！

部署完成後，您可以訪問：
- 主網站：https://vectorized.cc
- 備用網址：https://www.vectorized.cc

如有問題，請查看日誌檔案或聯繫技術支援。 
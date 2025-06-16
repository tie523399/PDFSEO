# PDF Master 部署指南

## 部署到 Ubuntu 22.04 x64 - vectorized.shop

本指南提供三種部署方式：

### 方式一：一鍵部署腳本（推薦）

1. **準備工作**
   - 確保您有 Ubuntu 22.04 x64 伺服器
   - 確保域名 vectorized.shop 已指向伺服器 IP
   - 確保有 root 權限的 SSH 訪問

2. **執行部署**
   ```bash
   # 在本地執行
   chmod +x quick-deploy.sh
   ./quick-deploy.sh
   ```

3. **腳本會自動完成**
   - 打包應用程式檔案
   - 上傳到伺服器
   - 安裝 Nginx
   - 配置 SSL (Let's Encrypt)
   - 設置反向代理
   - 配置防火牆
   - 創建備份腳本

### 方式二：手動部署

1. **連接到伺服器**
   ```bash
   ssh root@YOUR_SERVER_IP
   ```

2. **上傳檔案**
   ```bash
   # 在本地打包
   tar -czf pdfmaster.tar.gz index.html README.md robots.txt sitemap.xml seo-config.json api-mock.js
   
   # 上傳到伺服器
   scp pdfmaster.tar.gz deploy.sh root@YOUR_SERVER_IP:/root/
   ```

3. **在伺服器上執行**
   ```bash
   cd /root
   tar -xzf pdfmaster.tar.gz
   chmod +x deploy.sh
   ./deploy.sh
   ```

### 方式三：Docker 部署

1. **安裝 Docker 和 Docker Compose**
   ```bash
   # 在伺服器上執行
   curl -fsSL https://get.docker.com -o get-docker.sh
   sh get-docker.sh
   
   # 安裝 Docker Compose
   apt install docker-compose -y
   ```

2. **上傳所有檔案到伺服器**
   ```bash
   # 包含 Dockerfile, docker-compose.yml, nginx.conf, default.conf
   scp -r * root@YOUR_SERVER_IP:/root/pdfmaster/
   ```

3. **啟動服務**
   ```bash
   cd /root/pdfmaster
   docker-compose up -d
   ```

4. **配置 SSL**
   ```bash
   # 進入容器
   docker exec -it pdfmaster bash
   
   # 獲取 SSL 證書
   certbot --nginx -d vectorized.shop -d www.vectorized.shop
   ```

## SSL 證書配置

### 自動配置（使用部署腳本）
部署腳本會自動使用 Let's Encrypt 配置 SSL 證書。

### 手動配置
```bash
# 安裝 Certbot
apt install certbot python3-certbot-nginx -y

# 獲取證書
certbot --nginx -d vectorized.shop -d www.vectorized.shop

# 設置自動更新
echo "0 3 * * * certbot renew --quiet" | crontab -
```

## 反向代理配置

Nginx 配置已包含反向代理設置：

- 靜態檔案：直接由 Nginx 提供
- API 請求：代理到 localhost:3000
- WebSocket：支援即時連接

## 部署後檢查

1. **檢查服務狀態**
   ```bash
   systemctl status nginx
   nginx -t  # 測試配置
   ```

2. **檢查 SSL 證書**
   ```bash
   certbot certificates
   ```

3. **查看日誌**
   ```bash
   tail -f /var/log/nginx/pdfmaster_access.log
   tail -f /var/log/nginx/pdfmaster_error.log
   ```

## 維護命令

### 更新應用程式
```bash
cd /var/www/pdfmaster
# 上傳新檔案後
systemctl reload nginx
```

### 備份
```bash
/root/scripts/backup-pdfmaster.sh
```

### 更新 SSL 證書
```bash
certbot renew
```

### 重啟服務
```bash
systemctl restart nginx
```

## 故障排除

### 問題：無法訪問網站
1. 檢查域名解析：`nslookup vectorized.shop`
2. 檢查防火牆：`ufw status`
3. 檢查 Nginx：`systemctl status nginx`

### 問題：SSL 證書錯誤
1. 檢查證書：`certbot certificates`
2. 重新獲取：`certbot --nginx -d vectorized.shop`

### 問題：502 Bad Gateway
1. 檢查後端服務：`systemctl status pdfmaster-api`
2. 查看錯誤日誌：`tail -f /var/log/nginx/error.log`

## 性能優化

1. **啟用 HTTP/2**
   - 已在 Nginx 配置中啟用

2. **啟用 Gzip 壓縮**
   - 已在 Nginx 配置中啟用

3. **設置緩存**
   - 靜態資源：1 年
   - HTML：1 小時

4. **CDN 整合（可選）**
   - Cloudflare
   - AWS CloudFront

## 安全建議

1. **定期更新系統**
   ```bash
   apt update && apt upgrade -y
   ```

2. **設置防火牆規則**
   - 只開放必要端口（80, 443, 22）

3. **監控日誌**
   - 設置日誌輪轉
   - 監控異常訪問

4. **備份策略**
   - 每日自動備份
   - 異地備份存儲

## 聯繫支援

如有問題，請查看：
- 應用程式日誌：`/var/log/nginx/`
- 系統日誌：`journalctl -xe`
- Nginx 錯誤：`nginx -t`

---

部署完成後，您的 PDF Master 應用程式將在 https://vectorized.shop 上線運行！ 
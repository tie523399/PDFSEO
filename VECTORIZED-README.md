# Vectorized.cc PDF Master

專業的線上 PDF 編輯器，支援 20 種語言，具備完整的 PDF 處理功能。

## 🚀 一鍵部署

在 Ubuntu 22.04 服務器上運行：

```bash
# 下載並運行部署腳本
wget https://raw.githubusercontent.com/tie523399/PDFSEO/main/vectorized-deploy.sh
sudo bash vectorized-deploy.sh
```

就這麼簡單！腳本會自動：
- 安裝所有依賴
- 配置 Nginx 和 SSL
- 設置自動更新（每 30 分鐘）
- 發送 Telegram 通知

## 📋 系統配置

- **域名**: vectorized.cc
- **Git 倉庫**: https://github.com/tie523399/PDFSEO.git
- **Telegram Bot**: 已配置自動通知
- **自動更新**: 每 30 分鐘檢查一次

## 🛠️ 管理命令

```bash
# 查看更新日誌
tail -f /var/log/pdfmaster-update.log

# 手動執行更新
sudo systemctl start pdfmaster-updater.service

# 查看自動更新狀態
sudo systemctl status pdfmaster-updater.timer

# 查看 Nginx 狀態
sudo systemctl status nginx

# 重啟 Nginx
sudo systemctl restart nginx
```

## 🔄 自動更新系統

系統會自動：
1. 每 30 分鐘檢查 Git 更新
2. 發現更新時自動拉取並部署
3. 更新前自動備份
4. 更新失敗時自動回滾
5. 通過 Telegram 發送通知

## 📁 文件結構

```
/var/www/pdfmaster/          # 應用目錄
/var/log/pdfmaster-update.log # 更新日誌
/var/backups/pdfmaster/      # 自動備份
/usr/local/bin/auto-update.sh # 自動更新腳本
```

## 🔧 故障排除

如果遇到問題：

1. **檢查日誌**：
   ```bash
   sudo tail -f /var/log/pdfmaster-update.log
   sudo journalctl -u pdfmaster-updater.service -f
   ```

2. **重新部署**：
   ```bash
   cd /var/www/pdfmaster
   sudo bash vectorized-deploy.sh
   ```

3. **手動更新**：
   ```bash
   cd /var/www/pdfmaster
   git pull
   sudo systemctl restart nginx
   ```

## 📞 支援

通過 Telegram Bot 接收系統通知和狀態更新。 
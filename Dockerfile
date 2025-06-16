# PDF Master Docker 映像
FROM nginx:alpine

# 安裝必要的工具
RUN apk add --no-cache \
    certbot \
    certbot-nginx \
    openssl \
    curl

# 複製應用程式檔案
COPY index.html /usr/share/nginx/html/
COPY README.md /usr/share/nginx/html/
COPY robots.txt /usr/share/nginx/html/
COPY sitemap.xml /usr/share/nginx/html/
COPY seo-config.json /usr/share/nginx/html/
COPY api-mock.js /usr/share/nginx/html/

# 創建 SSL 證書目錄
RUN mkdir -p /etc/letsencrypt

# 複製 Nginx 配置
COPY nginx.conf /etc/nginx/nginx.conf
COPY default.conf /etc/nginx/conf.d/default.conf

# 設置工作目錄
WORKDIR /usr/share/nginx/html

# 暴露端口
EXPOSE 80 443

# 健康檢查
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost/ || exit 1

# 啟動 Nginx
CMD ["nginx", "-g", "daemon off;"] 
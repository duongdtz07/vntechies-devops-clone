#!/bin/bash
set -e

# Cập nhật hệ thống và cài đặt công cụ cần thiết
dnf update -y
dnf install -y git nginx nodejs npm

# Cấu hình Swap 2GB (tránh OOM khi npm install / build trên t3.micro)
if [ ! -f /swapfile ]; then
    dd if=/dev/zero of=/swapfile bs=128M count=16
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo "/swapfile swap swap defaults 0 0" >> /etc/fstab
fi

# Clone source code từ GitHub
APP_DIR="/opt/app"
rm -rf "$APP_DIR"
git clone https://github.com/duongdtz07/test-aws.git "$APP_DIR"

# Cài đặt dependency và build ứng dụng Next.js
cd "$APP_DIR"
npm install
npm run build

# Cấu hình Systemd Service để chạy Next.js tự động dưới nền
cat <<'SERVICE' > /etc/systemd/system/nextjs.service
[Unit]
Description=Next.js Web Application
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/app
ExecStart=/usr/bin/npm start
Restart=always
RestartSec=10
Environment=NODE_ENV=production
Environment=PORT=3000

[Install]
WantedBy=multi-user.target
SERVICE

systemctl daemon-reload
systemctl enable nextjs
systemctl start nextjs

# Cấu hình Nginx Reverse Proxy (chuyển tiếp Port 80 về Port 3000)
cat <<'NGINX' > /etc/nginx/nginx.conf
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log notice;
pid /run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;
    sendfile        on;
    keepalive_timeout  65;

    server {
        listen 80 default_server;
        server_name _;

        location / {
            proxy_pass http://127.0.0.1:3000;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host $host;
            proxy_cache_bypass $http_upgrade;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
    }
}
NGINX

systemctl enable nginx
systemctl restart nginx

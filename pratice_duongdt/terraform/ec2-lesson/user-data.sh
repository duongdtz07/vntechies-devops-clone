#!/bin/bash
set -e

# Cập nhật hệ thống và cài đặt công cụ cần thiết
dnf update -y
# dnf install -y git nginx nodejs npm  # Ghi chú: Lệnh mặc định này cài Node.js 18, không tương thích với Next.js (yêu cầu Node.js >= 20.9.0)
dnf install -y git nginx

# Cài đặt Node.js 20 LTS (Next.js yêu cầu Node.js >= 20.9.0)
curl -fsSL https://rpm.nodesource.com/setup_20.x | bash -
dnf install -y nodejs

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

# ==============================================================================
# NOTE / POST-MORTEM VỀ LỖI UNHEALTHY & VÒNG LẶP XOÁ/TẠO EC2 TRƯỚC ĐÓ:
# ==============================================================================
# 1. Hiện tượng:
#    - EC2 sau khi khởi tạo được khoảng 5 phút thì bị Auto Scaling Group xoá đi
#      và tạo lại con mới liên tục (flapping/recreation loop).
#
# 2. Nguyên nhân gốc rễ (Root Cause):
#    - Lệnh mặc định `dnf install -y nodejs` trên Amazon Linux 2023 cài Node.js 18.20.8.
#    - Source code Next.js trong repo test-aws yêu cầu Node.js >= 20.9.0.
#    - Khi chạy đến `npm run build`, Next.js báo lỗi không tương thích phiên bản
#      và trả về exit code 1.
#    - Do có `set -e` ở đầu file, script bị dừng ngay lập tức, các lệnh bên dưới
#      (chạy Next.js service và khởi động Nginx) không bao giờ được thực thi.
#    - Port 80 không có dịch vụ lắng nghe -> ALB Health Check thất bại (Unhealthy).
#    - ASG có `health_check_type = "ELB"` thấy instance Unhealthy sau grace period (300s)
#      liền tự động huỷ và tạo lại máy mới.
#
# 3. Cách khắc phục:
#    - Cài đặt Node.js 20 LTS từ kho NodeSource (`rpm.nodesource.com/setup_20.x`).
# ==============================================================================

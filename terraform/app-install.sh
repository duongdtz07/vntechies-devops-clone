#!/bin/bash
set -e
exec > /var/log/user-data.log 2>&1

# ─── FILL THESE IN ────────────────────────────────────────────
GITHUB_REPO="https://github.com/homielab/giapha-os.git"
SUPABASE_URL=""
SUPABASE_KEY=""
# ──────────────────────────────────────────────────────────────

APP_DIR="/home/ec2-user/giapha-os"
BUN="/home/ec2-user/.bun/bin/bun"

echo ">>> Updating system..."
yum update -y
yum install -y git

echo ">>> Installing Node.js 24..."
curl -fsSL https://rpm.nodesource.com/setup_24.x | bash -
yum install -y nodejs

echo ">>> Installing PM2..."
npm install -g pm2

echo ">>> Installing Nginx..."
yum install nginx -y

echo ">>> Installing Bun..."
su - ec2-user -c 'curl -fsSL https://bun.sh/install | bash'

echo ">>> Cloning repo..."
su - ec2-user -c "git clone $GITHUB_REPO $APP_DIR"

echo ">>> Writing .env.local..."
cat > $APP_DIR/.env.local << EOF
SITE_NAME="Gia Phả OS"
NEXT_PUBLIC_SUPABASE_URL="$SUPABASE_URL"
NEXT_PUBLIC_SUPABASE_PUBLISHABLE_DEFAULT_KEY="$SUPABASE_KEY"
EOF
chown ec2-user:ec2-user $APP_DIR/.env.local

echo ">>> Installing dependencies and building..."
su - ec2-user -c "cd $APP_DIR && $BUN install && $BUN run build"

echo ">>> Starting app with PM2..."
su - ec2-user -c "cd $APP_DIR && /usr/bin/pm2 start '$BUN run start' --name giapha-os"
su - ec2-user -c '/usr/bin/pm2 save'

echo ">>> Setting up PM2 on reboot..."
/usr/bin/pm2 startup systemd -u ec2-user --hp /home/ec2-user
systemctl enable pm2-ec2-user

echo ">>> Configuring Nginx..."
cat > /etc/nginx/conf.d/giapha-os.conf << 'EOF'
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
}
EOF

systemctl enable nginx
systemctl start nginx

echo ">>> Done! App should be running at http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"

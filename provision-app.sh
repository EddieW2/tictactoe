
#!/bin/bash
set -Eeuo pipefail

# Log all setup output for troubleshooting
exec > >(tee -a /var/log/tictactoe-setup.log) 2>&1

# ==========================================
# CONFIGURATION
# ==========================================
APP_NAME="tictactoe"
APP_DIR="/opt/tictactoe"
ZIP_FILE="/tmp/nodejs20-sparta-tictactoe-v1.zip"
NODE_VERSION="20"
PORT="3000"

# Replace with your actual GitHub Release asset URL
ZIP_URL="https://raw.githubusercontent.com/EddieW2/tictactoe/main/nodejs20-sparta-tictactoe-v1.zip"

echo "==> Starting $APP_NAME deployment..."

# ==========================================
# 1. INSTALL DEPENDENCIES
# ==========================================
apt-get update -y
apt-get install -y curl unzip nginx

# Install Node.js 20
if ! command -v node >/dev/null 2>&1 || \
   [ "$(node -p 'process.versions.node.split(".")[0]')" -lt "$NODE_VERSION" ]; then
    curl -fsSL https://deb.nodesource.com/setup_20.x -o /tmp/nodesource_setup.sh
    bash /tmp/nodesource_setup.sh
    apt-get install -y nodejs
fi

# Install PM2
if ! command -v pm2 >/dev/null 2>&1; then
    npm install -g pm2
fi

# ==========================================
# 2. DOWNLOAD APPLICATION FROM GITHUB
# ==========================================
echo "==> Downloading application..."

curl -fL --retry 3 "$ZIP_URL" -o "$ZIP_FILE"

mkdir -p "$APP_DIR"
unzip -oq "$ZIP_FILE" -d "$APP_DIR"

# Check application files
cd "$APP_DIR"

if [ ! -f package.json ]; then
    echo "ERROR: package.json not found at $APP_DIR."
    echo "The ZIP may contain an extra top-level folder."
    find "$APP_DIR" -maxdepth 3 -name package.json
    exit 1
fi

if [ ! -f index.js ]; then
    echo "ERROR: index.js not found at $APP_DIR."
    exit 1
fi

# ==========================================
# 3. INSTALL NODE DEPENDENCIES
# ==========================================
echo "==> Installing npm dependencies..."

if [ -f package-lock.json ]; then
    npm ci
else
    npm install
fi

# ==========================================
# 4. CONFIGURE NGINX REVERSE PROXY
# ==========================================
echo "==> Configuring Nginx..."

cat > /etc/nginx/sites-available/tictactoe <<EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    server_name _;

    location / {
        proxy_pass http://127.0.0.1:${PORT};
        proxy_http_version 1.1;

        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

ln -sfn /etc/nginx/sites-available/tictactoe \
    /etc/nginx/sites-enabled/tictactoe

rm -f /etc/nginx/sites-enabled/default

nginx -t
systemctl enable nginx
systemctl restart nginx

# ==========================================
# 5. START APPLICATION USING PM2
# ==========================================
echo "==> Starting application..."

cd "$APP_DIR"

if pm2 describe "$APP_NAME" >/dev/null 2>&1; then
    pm2 restart "$APP_NAME" --update-env
else
    pm2 start index.js --name "$APP_NAME" \
        --cwd "$APP_DIR"
fi

# Save the process list
pm2 save

# ==========================================
# 6. ENABLE AUTOMATIC STARTUP
# ==========================================
echo "==> Configuring PM2 startup..."

PM2_STARTUP_CMD="$(pm2 startup systemd -u root --hp /root 2>&1 \
    | grep -o 'sudo env.*' || true)"

if [ -n "$PM2_STARTUP_CMD" ]; then
    eval "$PM2_STARTUP_CMD"
fi

systemctl enable pm2-root

echo "==> Deployment complete!"
echo "==> Access the app using your EC2 public IP."
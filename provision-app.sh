
#!/bin/bash

# Stop the script if a command fails, and log all output.
set -Ee
exec > >(tee -a /var/log/user-data-deploy.log) 2>&1

echo "Starting Tic-Tac-Toe deployment..."

# Update Ubuntu and install required packages.
apt-get update
apt-get upgrade -y
apt-get install -y curl unzip nginx git

# Install Node.js 20.
curl -fsSL https://deb.nodesource.com/setup_20.x \
    -o /tmp/nodesource_setup.sh
bash /tmp/nodesource_setup.sh
apt-get install -y nodejs

# Install PM2.
npm install -g pm2

# Clone the application from GitHub.
cd /home/ubuntu
rm -rf tictactoe
git clone https://github.com/EddieW/tictactoe.git
cd tictactoe

# Check that the expected ZIP file exists.
if [ ! -f nodejs20-sparta-tictactoe-v1.zip ]; then
    echo "ERROR: Application ZIP file not found."
    exit 1
fi

# Extract the application.
unzip -o nodejs20-sparta-tictactoe-v1.zip -d /home/ubuntu/tictactoe
cd /home/ubuntu/tictactoe/app

# Install Node.js dependencies.
npm install

# Run PM2 as the ubuntu user, not root.
chown -R ubuntu:ubuntu /home/ubuntu/tictactoe

# Start or replace the application.
runuser -u ubuntu -- pm2 delete tictactoe || true
runuser -u ubuntu -- pm2 start index.js --name tictactoe

# Configure PM2 to restore the app after reboot.
runuser -u ubuntu -- pm2 save
env PATH="$PATH:/usr/bin" runuser -u ubuntu -- pm2 startup systemd -u ubuntu --hp /home/ubuntu

# Configure Nginx as a reverse proxy.
cat > /etc/nginx/sites-available/default <<'NGINX'
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    server_name _;

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
NGINX

# Validate Nginx before restarting it.
nginx -t
systemctl enable nginx
systemctl restart nginx

echo "Tic-Tac-Toe deployment completed."
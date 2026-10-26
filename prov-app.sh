#!/bin/bash

# ---- settings ----
APP_USER=ubuntu            # use your VM's admin user (Azure: e.g. adminuser)
APP_HOME=/home/$APP_USER
export DEBIAN_FRONTEND=noninteractive

echo "update the sources list..."
apt-get update -y

echo "upgrade any packages available..."
apt-get upgrade -y

echo "install nginx and git..."
apt-get install -y nginx git sed curl

echo "setup nginx reverse proxy..."
sed -i "s/try_files \$uri \$uri\/ =404;/proxy_pass http:\/\/localhost:3000\/;/" /etc/nginx/sites-available/default
systemctl restart nginx
systemctl enable nginx

echo "install nodejs v20..."
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs
node -v

# ---- choose ONE mode ----
# OPTION 1: set nothing
# OPTION 2:
# export STATEFUL_MODE=server
# OPTION 3 (DB VM must already be running):
# export MONGODB_URI=mongodb://<db-private-ip>:27017/tictactoe

echo "clone repo as $APP_USER..."
cd $APP_HOME
sudo -u $APP_USER git clone https://github.com/LSF970/tech613-tictactoe-app.git repo

echo "npm install..."
cd $APP_HOME/repo/app
sudo -u $APP_USER npm install

# OPTION 3 only: seed the database
# sudo -u $APP_USER MONGODB_URI=$MONGODB_URI node seeds/seed.js

echo "install pm2..."
npm install pm2 -g

echo "start the app with pm2..."
# -E passes the exported env vars (STATEFUL_MODE / MONGODB_URI) through sudo
sudo -E -u $APP_USER env PATH=$PATH:/usr/bin pm2 start index.js --name tic
sudo -u $APP_USER pm2 save

echo "make pm2 restart the app on reboot..."
env PATH=$PATH:/usr/bin pm2 startup systemd -u $APP_USER --hp $APP_HOME

echo "user data finished"
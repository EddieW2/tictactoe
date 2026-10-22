#!/bin/bash
# Update and upgrade
sudo apt update
sudo apt upgrade -y

# Installs packages
sudo apt install unzip nginx git -y

# Download nodejs
# and  save it in the file nodesource_setup.sh
curl -sL https://deb.nodesource.com/setup_20.x -o nodesource_setup.sh

# Run the Nodejs with administrator privileges
sudo bash nodesource_setup.sh

# Install Node.js and pm2
sudo apt install nodejs -y
sudo npm install -g pm2

# clone each run
cd ~
rm -rf tictactoe
git clone https://github.com/EddieW/tictactoe.git
cd tictactoe

# Unzip 
if [ -f nodejs20-sparta-tictactoe-v1.zip ]; then
    unzip -o nodejs20-sparta-tictactoe-v1.zip
    cd app
    npm install

    # Remove any existing tictactoe web-apps
    pm2 delete tictactoe || true

    # Start the app changes name
    pm2 start index.js --name tictactoe

    # Reverse proxy
    sudo sed -i 's|try_files \$uri \$uri/ =404;|proxy_pass http://localhost:3000;|' /etc/nginx/sites-available/default

    # config is valid, and only reload nginx if it is
    sudo nginx -t && sudo systemctl reload nginx         

else
    echo "Cannot find zip file needed"
fi
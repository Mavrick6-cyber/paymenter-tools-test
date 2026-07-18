#!/bin/bash

if [ "$(id -u)" -ne 0 ]; then
    echo "❌ Run as root: sudo bash setup-paymenter.sh"
    exit 1
fi

clear
echo "=========================================="
echo "       Paymenter Installer"
echo "=========================================="
echo ""

read -p "Database Name [paymenter]: " DB_DATABASE
DB_DATABASE=${DB_DATABASE:-paymenter}

read -p "Database Username [paymenter]: " DB_USERNAME
DB_USERNAME=${DB_USERNAME:-paymenter}

read -s -p "Database Password: " DB_PASSWORD
echo ""

read -p "Domain (e.g. billing.yoursite.com): " DOMAIN

read -p "Admin Email: " ADMIN_EMAIL

read -s -p "Admin Password: " ADMIN_PASSWORD
echo ""
echo ""

echo "Installing..."
echo ""

# Install dependencies
# shellcheck source=/etc/os-release
. /etc/os-release
if [ "$ID" = "debian" ]; then
    apt -y install curl ca-certificates gnupg2 sudo lsb-release
    echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/sury-php.list
    curl -fsSL https://packages.sury.org/php/apt.gpg | gpg --dearmor -o /etc/apt/trusted.gpg.d/sury-keyring.gpg
else
    apt -y install software-properties-common curl apt-transport-https ca-certificates gnupg
    LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php
fi
apt update
apt -y install php8.3 php8.3-{common,cli,gd,mysql,mbstring,bcmath,xml,fpm,curl,zip,intl,redis} mariadb-server nginx tar unzip git redis-server

# Download Paymenter
echo "Downloading Paymenter..."
mkdir -p /var/www/paymenter
mkdir -p /tmp/paymenter-install
cd /tmp/paymenter-install
curl -Lo paymenter.tar.gz https://github.com/paymenter/paymenter/releases/latest/download/paymenter.tar.gz
tar -xzf paymenter.tar.gz

# Check if files are in a subdirectory or directly extracted
if [ -d "paymenter" ]; then
    cp -a paymenter/* /var/www/paymenter/
    cp -a paymenter/.* /var/www/paymenter/ 2>/dev/null
elif [ -f ".env.example" ]; then
    cp -a ./* /var/www/paymenter/
    cp -a .[!.]* /var/www/paymenter/ 2>/dev/null
else
    echo "❌ Failed to extract Paymenter files"
    ls -la
    exit 1
fi

rm -rf /tmp/paymenter-install
cd /var/www/paymenter
chmod -R 755 storage bootstrap/cache

# Verify extraction worked
if [ ! -f ".env.example" ]; then
    echo "❌ .env.example not found after extraction"
    echo "   Files in /var/www/paymenter:"
    ls -la /var/www/paymenter/
    exit 1
fi

# Database
mysql -u root -e "CREATE USER IF NOT EXISTS '$DB_USERNAME'@'127.0.0.1' IDENTIFIED BY '$DB_PASSWORD';"
mysql -u root -e "CREATE DATABASE IF NOT EXISTS \`$DB_DATABASE\`;"
mysql -u root -e "GRANT ALL PRIVILEGES ON \`$DB_DATABASE\`.* TO '$DB_USERNAME'@'127.0.0.1' WITH GRANT OPTION;"
mysql -u root -e "FLUSH PRIVILEGES;"

# Configure .env
if [ ! -f .env.example ]; then
    echo "❌ .env.example not found in /var/www/paymenter"
    echo "   Contents: $(ls -la /var/www/paymenter)"
    exit 1
fi
cp .env.example .env
sed -i "s/^DB_DATABASE=.*/DB_DATABASE=$DB_DATABASE/" .env
sed -i "s/^DB_USERNAME=.*/DB_USERNAME=$DB_USERNAME/" .env
ESCAPED_PASS=$(printf '%s\n' "$DB_PASSWORD" | sed 's/[&/\\]/\\&/g')
sed -i "s/^DB_PASSWORD=.*/DB_PASSWORD=$ESCAPED_PASS/" .env
php artisan key:generate --force
php artisan storage:link

# Database setup
php artisan migrate --force --seed
php artisan db:seed --class=CustomPropertySeeder
php artisan app:init

# Create admin user
php artisan app:user:create "$ADMIN_EMAIL" "$ADMIN_PASSWORD"

# Nginx
cat > /etc/nginx/sites-available/paymenter.conf <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN;
    root /var/www/paymenter/public;

    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-Content-Type-Options "nosniff";

    index index.php;

    charset utf-8;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ ^/index\.php(/|$) {
        fastcgi_pass unix:/var/run/php/php8.3-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$realpath_root\$fastcgi_script_name;
        include fastcgi_params;
        fastcgi_hide_header X-Powered-By;
    }
}
EOF
ln -sf /etc/nginx/sites-available/paymenter.conf /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl restart nginx
systemctl enable nginx

# Cronjob & queue worker
(crontab -u www-data -l 2>/dev/null; echo "* * * * * php /var/www/paymenter/artisan schedule:run >> /dev/null 2>&1") | crontab -u www-data -

cat > /etc/systemd/system/paymenter.service <<'EOF'
[Unit]
Description=Paymenter Queue Worker
[Service]
User=www-data
Group=www-data
Restart=always
ExecStart=/usr/bin/php /var/www/paymenter/artisan queue:work
StartLimitInterval=180
StartLimitBurst=30
RestartSec=5s
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now paymenter.service

# Start services & set ownership
systemctl enable --now php8.3-fpm
systemctl enable --now mariadb
systemctl enable --now redis-server
chown -R www-data:www-data /var/www/paymenter/*

# Install certbot
apt -y install certbot python3-certbot-nginx

# Save key
grep "^APP_KEY=" .env | cut -d'=' -f2- > /root/paymenter-app-key.txt
chmod 600 /root/paymenter-app-key.txt

echo ""
echo ""
echo "  ╔══════════════════════════════════════╗"
echo "  ║                                      ║"
echo "  ║     ⚡ MISFIT STUDIOS AND HOSTING ⚡  ║"
echo "  ║                                      ║"
echo "  ╚══════════════════════════════════════╝"
echo ""
echo "  ✅ Paymenter has been installed successfully!"
echo ""
echo "  Open your browser and go to:"
echo "  👉 https://$DOMAIN"
echo ""
echo "  Admin Login:"
echo "  Email:    $ADMIN_EMAIL"
echo "  Password: (the one you just entered)"
echo ""
echo "  Your encryption key has been saved to:"
echo "  /root/paymenter-app-key.txt"
echo ""
echo "  ─────────────────────────────────────"
echo "  Thank you for using the Misfit Hosting"
echo "  Easy Installer! — Misfit Studios & Hosting"
echo "  ─────────────────────────────────────"
echo ""
echo "  Need support?"
echo "  Join our Discord: https://discord.gg/mFcXchfsYF"
echo "  Submit a ticket and reference: Paymenter Script Installation"
echo ""

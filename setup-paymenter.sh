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
mkdir -p /var/www/paymenter
cd /var/www/paymenter
curl -Lo paymenter.tar.gz https://github.com/paymenter/paymenter/releases/latest/download/paymenter.tar.gz
tar -xzvf paymenter.tar.gz
rm paymenter.tar.gz
chmod -R 755 storage bootstrap/cache

# Database
mysql -u root -e "CREATE USER IF NOT EXISTS '$DB_USERNAME'@'127.0.0.1' IDENTIFIED BY '$DB_PASSWORD';"
mysql -u root -e "CREATE DATABASE IF NOT EXISTS \`$DB_DATABASE\`;"
mysql -u root -e "GRANT ALL PRIVILEGES ON \`$DB_DATABASE\`.* TO '$DB_USERNAME'@'127.0.0.1' WITH GRANT OPTION;"
mysql -u root -e "FLUSH PRIVILEGES;"

# Configure .env
cp .env.example .env
sed -i "s/^DB_DATABASE=.*/DB_DATABASE=$DB_DATABASE/" .env
sed -i "s/^DB_USERNAME=.*/DB_USERNAME=$DB_USERNAME/" .env
sed -i "s/^DB_PASSWORD=.*/DB_PASSWORD=$DB_PASSWORD/" .env
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
(crontab -l 2>/dev/null; echo "* * * * * php /var/www/paymenter/artisan schedule:run >> /dev/null 2>&1") | crontab -

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

# Save key
grep "^APP_KEY=" .env | cut -d'=' -f2- > /root/paymenter-app-key.txt
chmod 600 /root/paymenter-app-key.txt

echo ""
echo "=========================================="
echo "✅ Done! Paymenter is installed."
echo "=========================================="
echo ""
echo "  Domain:    https://$DOMAIN"
echo "  Admin:     $ADMIN_EMAIL"
echo "  App Key:   /root/paymenter-app-key.txt"
echo ""
echo "  Next: certbot --nginx -d $DOMAIN"
echo "=========================================="

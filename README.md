# 🚀 Paymenter Auto-Setup Script

This script automates the full installation and configuration of **Paymenter** on Ubuntu/Debian servers. It handles everything from installing dependencies (PHP, MariaDB, Nginx, Redis) to downloading the latest release, configuring the database, and setting up your brand.

---

## ⚡ The One-Liner

To run this script on your server instantly, copy and paste this command into a terminal as root:

```bash
bash <(curl -s https://raw.githubusercontent.com/Mavrick6-cyber/paymenter-tools/main/setup-paymenter.sh)
```

Or with sudo:

```bash
sudo bash <(curl -s https://raw.githubusercontent.com/Mavrick6-cyber/paymenter-tools/main/setup-paymenter.sh)
```

---

## What It Does

1. **Installs all required dependencies**: PHP 8.3, MariaDB, Nginx, Redis, and required PHP extensions
2. **Downloads the latest Paymenter release** from GitHub
3. **Creates and configures the database**
4. **Sets up your `.env` file** with database credentials
5. **Runs migrations and seeds** the database
6. **Applies your brand settings** (company name and URL)
7. **Configures Nginx** with proper routing
8. **Sets correct file permissions** for the web server

## Requirements

- **OS**: Ubuntu 24.04 or Debian 11/12/13
- **User**: Root access
- **Network**: Internet connection (to download packages and Paymenter)

## Interactive Setup

The script will prompt you for:

- **Database credentials** (name, username, password)
- **Company name** (for branding)
- **App URL** (e.g., https://billing.yoursite.com)

## Post-Installation

After setup completes, you may want to:

- Configure SSL with Let's Encrypt: `certbot --nginx -d yourdomain.com`
- Set up a cron job: `* * * * * cd /var/www/paymenter && php artisan schedule:run >> /dev/null 2>&1`
- Configure a queue worker for background tasks

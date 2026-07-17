# 🚀 Paymenter Installer

One-command installer for **Paymenter** on Ubuntu/Debian servers.

## Install

```bash
bash <(curl -s https://raw.githubusercontent.com/Mavrick6-cyber/paymenter-tools/main/setup-paymenter.sh)
```

## What It Does

1. Installs PHP 8.3, MariaDB, Nginx, Redis
2. Downloads latest Paymenter release
3. Creates database and configures `.env`
4. Runs migrations and seeds
5. Creates your admin user
6. Configures Nginx
7. Sets up cronjob and queue worker

## Requirements

- Ubuntu 24.04/22.04 or Debian 13/12/11
- Root access
- Internet connection

## After Install

```bash
# Set up SSL
certbot --nginx -d yourdomain.com

# Backup your encryption key
cat /root/paymenter-app-key.txt
```

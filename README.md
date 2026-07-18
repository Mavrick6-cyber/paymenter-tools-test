# 🚀 Paymenter Installer

One-command installer for **Paymenter** on Ubuntu 24.04 servers.

## Install

```bash
bash <(curl -s https://raw.githubusercontent.com/Mavrick6-cyber/paymenter-tools-test/main/setup-paymenter.sh)
```

## What It Does

1. Installs PHP 8.3, MariaDB, Nginx, Redis
2. Downloads latest Paymenter release
3. Creates database and configures `.env`
4. Runs migrations and seeds
5. Creates your admin user
6. Configures Nginx
7. Sets up cronjob and queue worker
8. Automatically installs SSL and redirects HTTP → HTTPS

## Requirements

- Ubuntu 24.04
- Root access
- Internet connection
- A domain or DuckDNS domain pointed to your server's IP **before** running the installer

## Domain Setup

Before running the installer, make sure your domain is pointed to your server:

**Regular Domain:**
- Create an `A record` pointing to your server's public IP address
- Example: `billing.yoursite.com` → `123.456.789.0`

**DuckDNS:**
- Go to [https://www.duckdns.org](https://www.duckdns.org) and log in
- Create a subdomain (e.g. `myhosting.duckdns.org`)
- Set the IP to your server's public IP address
- Use `myhosting.duckdns.org` as your domain when prompted during install

> ⚠️ DNS must be pointed and propagated before running the installer or SSL will fail.

## Install Time

The installer takes approximately **5–8 minutes** depending on your server speed and internet connection.

| Step | Time |
|------|------|
| Apt installs (PHP, MariaDB, Nginx, Redis) | 2–4 mins |
| Paymenter download & extract | 30–60 secs |
| Database migrations & seeds | 1–2 mins |
| SSL (Certbot) | 30–60 secs |

## After Install

```bash
# Backup your encryption key
cat /root/paymenter-app-key.txt
```

> SSL is configured automatically during install. No manual certbot step needed.

## Support

Need help? Join the Misfit Studios & Hosting Discord:
👉 [https://discord.gg/mFcXchfsYF](https://discord.gg/mFcXchfsYF)

Submit a ticket and reference: **Paymenter Script Installation**

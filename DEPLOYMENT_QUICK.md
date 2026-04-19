# Voyfy VPN - Quick Deployment Guide

## Server Details
- **IP:** 185.164.163.166
- **Domain:** vip.necsoura.ru
- **Frontend:** https://vip.necsoura.ru
- **Admin Panel:** https://vip.necsoura.ru/admin
- **API:** https://vip.necsoura.ru/api

## Quick Deployment (One Command)

```bash
# Upload deploy.sh to server and run
scp deploy.sh root@185.164.163.166:/root/
ssh root@185.164.163.166
chmod +x deploy.sh
./deploy.sh
```

The script will:
- ✅ Install all dependencies (Node.js, PostgreSQL, Docker, Nginx)
- ✅ Setup database with random secure password
- ✅ Generate Xray keys automatically
- ✅ Configure backend with PM2
- ✅ Build and deploy frontend
- ✅ Setup Nginx with SSL (Let's Encrypt)
- ✅ Configure Xray VPN server
- ✅ Setup firewall
- ✅ Save all credentials

## Manual Deployment

See [DEPLOYMENT.md](./DEPLOYMENT.md) for detailed manual deployment instructions.

## After Deployment

### 1. Access Admin Panel
Go to: https://vip.necsoura.ru/admin

### 2. Generate Pairing Code
In admin panel, generate a pairing code for server registration.

### 3. Register Server
```bash
# On the same VPS, run:
./register-server.sh <pairing_code>
```

### 4. Update Flutter App
Change API URL in Flutter app to:
```dart
final uri = Uri.parse('https://vip.necsoura.ru/api/servers');
```

### 5. Test Connection
- Open Flutter app
- Server should appear in the list
- Select and connect

## Port Configuration

| Service | Port | External Access |
|---------|------|-----------------|
| Frontend | 443 | ✅ Yes (HTTPS) |
| Admin Panel | 443 | ✅ Yes (HTTPS) |
| API | 443 | ✅ Yes (proxied) |
| VPN (Xray) | 8443 | ✅ Yes |
| Backend (internal) | 4000 | ❌ No (nginx proxy) |
| Xray API (internal) | 10085 | ❌ No (local only) |
| PostgreSQL | 5432 | ❌ No (local only) |

## Services Status Check

```bash
# Backend
pm2 status
pm2 logs voyfy-backend

# Xray
docker ps
docker logs xray

# Nginx
systemctl status nginx
sudo tail -f /var/log/nginx/voyfy_access.log

# PostgreSQL
systemctl status postgresql
sudo -u postgres psql -d voyfy_vpn -c "SELECT version();"
```

## Firewall Rules

```bash
sudo ufw status
```

Allowed ports:
- 22/tcp (SSH)
- 80/tcp (HTTP)
- 443/tcp (HTTPS)
- 8443/tcp (VPN)

## SSL Certificate Renewal

Auto-renewal is configured via cron job (daily at midnight).

Manual renewal:
```bash
sudo certbot renew
sudo systemctl reload nginx
```

## Troubleshooting

### Backend not responding
```bash
pm2 restart voyfy-backend
pm2 logs voyfy-backend
```

### Xray not connecting
```bash
docker restart xray
docker logs xray
sudo netstat -tulpn | grep 8443
```

### SSL certificate expired
```bash
sudo certbot renew
sudo systemctl reload nginx
```

### Server not appearing in Flutter app
```bash
# Check API is accessible
curl https://vip.necsoura.ru/api/servers

# Check CORS settings
cat /var/www/voyfy-vpn/backend/.env | grep CORS
```

## Security Checklist

- [ ] Change default admin password
- [ ] Keep .env file secure (chmod 600)
- [ ] Regular updates: `sudo apt update && sudo apt upgrade -y`
- [ ] Monitor logs for suspicious activity
- [ ] Backup database regularly
- [ ] Use strong SSH keys instead of password
- [ ] Enable fail2ban for SSH protection

## Backup Database

```bash
sudo -u postgres pg_dump voyfy_vpn > backup_$(date +%Y%m%d).sql
```

## Restore Database

```bash
sudo -u postgres psql voyfy_vpn < backup_20250419.sql
```

## Support

For issues, check:
1. Service logs
2. Nginx error logs: `/var/log/nginx/voyfy_error.log`
3. Backend logs: `pm2 logs voyfy-backend`
4. Xray logs: `docker logs xray`

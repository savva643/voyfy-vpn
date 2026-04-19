# Voyfy VPN Deployment Guide

## Server Information
- **IP:** 185.164.163.166
- **Domain:** vip.necsoura.ru
- **Backend Port:** 4000
- **VPN Port:** 8443 (Xray)
- **Xray API Port:** 10085

## Prerequisites
- Ubuntu 20.04+ / Debian 11+
- Node.js 18+
- PostgreSQL 14+
- Nginx
- Docker (for Xray)
- SSL Certificate (Let's Encrypt)

## Step 1: System Preparation

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install required packages
sudo apt install -y curl git nginx postgresql postgresql-contrib docker.io docker-compose certbot python3-certbot-nginx

# Enable and start services
sudo systemctl enable nginx
sudo systemctl enable docker
sudo systemctl start nginx
sudo systemctl start docker
```

## Step 2: Setup PostgreSQL Database

```bash
# Switch to postgres user
sudo -u postgres psql

# Create database and user
CREATE DATABASE voyfy_vpn;
CREATE USER voyfy WITH ENCRYPTED PASSWORD 'your_strong_password_here';
GRANT ALL PRIVILEGES ON DATABASE voyfy_vpn TO voyfy;
\q

# Configure PostgreSQL to accept connections
sudo nano /etc/postgresql/14/main/postgresql.conf
# Uncomment and set: listen_addresses = '*'

sudo nano /etc/postgresql/14/main/pg_hba.conf
# Add at the end:
host    voyfy_vpn    voyfy    127.0.0.1/32    scram-sha-256
host    voyfy_vpn    voyfy    ::1/128         scram-sha-256

# Restart PostgreSQL
sudo systemctl restart postgresql
```

## Step 3: Clone Repository and Setup Backend

```bash
# Clone repository
cd /var/www
sudo git clone https://github.com/yourusername/voyfy-vpn.git
cd voyfy-vpn/backend

# Install dependencies
npm install

# Create .env file
sudo cp .env.example .env
sudo nano .env
```

Edit `.env` with your values:

```env
# Database
DB_HOST=localhost
DB_PORT=5432
DB_NAME=voyfy_vpn
DB_USER=voyfy
DB_PASSWORD=your_strong_password_here

# JWT (generate with: openssl rand -hex 32)
JWT_SECRET=your_generated_jwt_secret
JWT_REFRESH_SECRET=your_generated_refresh_secret

# Xray (generate with: docker run --rm teddysun/xray xray x25519)
XRAY_PUBLIC_KEY=your_xray_public_key
XRAY_PRIVATE_KEY=your_xray_private_key
XRAY_SERVER_NAME=www.microsoft.com
XRAY_SHORT_ID=your_short_id
XRAY_PORT=8443
XRAY_API_PORT=10085

# Server
PORT=4000
NODE_ENV=production
LOG_LEVEL=info

# CORS
CORS_ORIGIN=https://vip.necsoura.ru,https://185.164.163.166
FRONTEND_URL=https://vip.necsoura.ru
```

```bash
# Build and start backend
npm run build
sudo npm install -g pm2
pm2 start npm --name "voyfy-backend" -- start
pm2 save
pm2 startup
```

## Step 4: Setup Frontend

```bash
cd /var/www/voyfy-vpn/frontend

# Build frontend
npm install
npm run build

# Copy build to nginx directory
sudo mkdir -p /var/www/voyfy-vpn/frontend
sudo cp -r dist/* /var/www/voyfy-vpn/frontend/
sudo chown -R www-data:www-data /var/www/voyfy-vpn/frontend
```

## Step 5: Setup Nginx

```bash
# Copy nginx config
sudo cp /var/www/voyfy-vpn/nginx.conf /etc/nginx/sites-available/voyfy-vpn
sudo ln -s /etc/nginx/sites-available/voyfy-vpn /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# Test nginx config
sudo nginx -t

# Reload nginx
sudo systemctl reload nginx
```

## Step 6: Setup SSL with Let's Encrypt

```bash
# Stop nginx temporarily
sudo systemctl stop nginx

# Obtain SSL certificate
sudo certbot certonly --standalone -d vip.necsoura.ru -d 185.164.163.166

# Start nginx
sudo systemctl start nginx

# Setup auto-renewal
sudo certbot renew --dry-run
```

## Step 7: Setup Xray VPN Server

```bash
# Create Xray directory
sudo mkdir -p /etc/xray
cd /etc/xray

# Generate Xray keys
docker run --rm teddysun/xray xray x25519

# Output will show private and public keys, update your .env with these values

# Create xray config
sudo nano config.json
```

`/etc/xray/config.json`:

```json
{
  "log": {
    "loglevel": "warning"
  },
  "api": {
    "services": [
      "HandlerService",
      "LoggerService",
      "StatsService"
    ],
    "tag": "api"
  },
  "stats": {},
  "policy": {
    "levels": {
      "0": {
        "handshake": 4,
        "connIdle": 300,
        "uplinkOnly": 2,
        "downlinkOnly": 5,
        "bufferSize": 10240,
        "statsUserUplink": false,
        "statsUserDownlink": false
      }
    },
    "system": {
      "statsInboundUplink": false,
      "statsInboundDownlink": false,
      "statsOutboundUplink": false,
      "statsOutboundDownlink": false
    }
  },
  "inbounds": [
    {
      "port": 8443,
      "protocol": "vless",
      "settings": {
        "clients": [],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "dest": "www.microsoft.com:443",
          "serverNames": [
            "www.microsoft.com"
          ],
          "privateKey": "YOUR_PRIVATE_KEY_FROM_ENV",
          "shortIds": [
            "YOUR_SHORT_ID_FROM_ENV"
          ]
        }
      },
      "tag": "vless-reality"
    },
    {
      "listen": "127.0.0.1",
      "port": 10085,
      "protocol": "dokodemo-door",
      "settings": {
        "address": "127.0.0.1"
      },
      "tag": "api"
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "freedom"
    }
  ],
  "routing": {
    "domainStrategy": "AsIs",
    "rules": [
      {
        "type": "field",
        "inboundTag": [
          "api"
        ],
        "outboundTag": "api"
      }
    ]
  }
}
```

```bash
# Start Xray with Docker
docker run -d \
  --name xray \
  --restart=unless-stopped \
  -v /etc/xray:/etc/xray \
  -p 8443:8443 \
  -p 10085:10085 \
  teddysun/xray

# Verify Xray is running
docker logs xray
```

## Step 8: Configure Firewall

```bash
# Allow necessary ports
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 80/tcp    # HTTP
sudo ufw allow 443/tcp   # HTTPS
sudo ufw allow 8443/tcp  # VPN
sudo ufw allow 4000/tcp  # Backend (internal only, optional)

# Enable firewall
sudo ufw enable
```

## Step 9: Test Setup

```bash
# Test backend health
curl https://vip.necsoura.ru/api/health

# Test frontend
curl https://vip.necsoura.ru

# Test admin panel
curl https://vip.necsoura.ru/admin
```

## Step 10: Server Registration Flow

### In Admin Panel:
1. Go to https://vip.necsoura.ru/admin
2. Login with admin credentials
3. Generate a pairing code
4. Note the pairing code

### On VPS (same server):
```bash
# Register server with pairing code
curl -X POST https://vip.necsoura.ru/api/servers/register \
  -H "Content-Type: application/json" \
  -d '{
    "pairingCode": "YOUR_PAIRING_CODE",
    "host": "185.164.163.166",
    "port": 8443,
    "provider": "xray"
  }'
```

### Verify in Flutter App:
1. Update API URL in Flutter app to: `https://vip.necsoura.ru/api/servers`
2. Run app
3. Server should appear in the list
4. Select and connect

## Step 11: Monitor and Maintenance

```bash
# Check backend logs
pm2 logs voyfy-backend

# Check Xray logs
docker logs xray

# Check nginx logs
sudo tail -f /var/log/nginx/voyfy_access.log
sudo tail -f /var/log/nginx/voyfy_error.log

# Restart services if needed
pm2 restart voyfy-backend
docker restart xray
sudo systemctl reload nginx
```

## Troubleshooting

### Backend not starting:
```bash
pm2 logs voyfy-backend
# Check database connection in .env
```

### SSL certificate issues:
```bash
sudo certbot renew
sudo systemctl reload nginx
```

### Xray not connecting:
```bash
docker logs xray
# Check if ports 8443 and 10085 are open
sudo netstat -tulpn | grep -E '8443|10085'
```

### Server not appearing in Flutter app:
- Check API is accessible: `curl https://vip.necsoura.ru/api/servers`
- Verify CORS settings in .env
- Check Flutter app API URL configuration

## Security Notes

1. **Change all default passwords** in .env
2. **Keep JWT secrets secure** and rotate regularly
3. **Use strong database passwords**
4. **Enable firewall** and only open necessary ports
5. **Regular updates**: `sudo apt update && sudo apt upgrade -y`
6. **Monitor logs** for suspicious activity
7. **Backup database** regularly:
   ```bash
   sudo -u postgres pg_dump voyfy_vpn > backup.sql
   ```

## Flutter App Configuration

Update API URL in Flutter app:

```dart
// In lib/screens/server_location.dart
final uri = Uri.parse('https://vip.necsoura.ru/api/servers');

// In lib/screens/home_screen.dart
final uri = Uri.parse('https://vip.necsoura.ru/api/servers');
```

## Summary of Ports

| Service | Port | Protocol | Purpose |
|---------|------|----------|---------|
| Backend API | 4000 | HTTP | Internal API (proxied by nginx) |
| Frontend | 80/443 | HTTP/HTTPS | Nginx serves static files |
| Admin Panel | 80/443 | HTTP/HTTPS | Proxied through nginx |
| VPN (Xray) | 8443 | TCP | VPN client connections |
| Xray API | 10085 | TCP | Xray management API |
| PostgreSQL | 5432 | TCP | Database (local only) |

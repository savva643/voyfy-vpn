# Server Deployment Guide

Quick start guide for deploying Voyfy VPN server.

## Requirements

- Ubuntu 20.04/22.04/24.04 or Debian 11/12
- Root or sudo access
- Domain name pointing to your server (optional, for SSL)

## Quick Deploy

```bash
# 1. Clone repository
git clone https://github.com/savva643/voyfy-vpn.git /opt/voyfy-vpn
cd /opt/voyfy-vpn

# 2. Make deploy script executable
chmod +x deploy.sh

# 3. Run deployment
./deploy.sh
```

The script will:
1. Update system packages
2. Install Docker and Docker Compose
3. Clone/update the repository
4. Generate Xray keys automatically
5. Download Xray binaries for all platforms
6. Build and start all services
7. Configure firewall (UFW)
8. Setup SSL with Let's Encrypt (if domain provided)

## Manual Steps (if needed)

### Generate Xray Keys Manually

If automatic key generation fails:

```bash
cd /opt/voyfy-vpn/docker
docker run --rm teddysun/xray xray x25519
```

Copy the keys to `.env` file:
```
XRAY_PUBLIC_KEY=your-public-key-here
XRAY_PRIVATE_KEY=your-private-key-here
```

### Restart Services

```bash
cd /opt/voyfy-vpn/docker
docker-compose down
docker-compose up -d
```

### View Logs

```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f backend
docker-compose logs -f xray
```

## Default Ports

- `443` - Xray VPN (VLESS+Reality)
- `4000` - Backend API
- `80` - HTTP (redirects to HTTPS)

## Post-Deployment

After successful deployment:

1. **Backend API**: `https://your-domain.com:4000` or `http://your-server-ip:4000`
2. **VPN Server**: Running on port 443
3. **Admin**: Use the API to manage servers and users

## Update Server

To update to latest version:

```bash
cd /opt/voyfy-vpn
git pull
./deploy.sh
```

## Troubleshooting

### Docker not starting

```bash
sudo systemctl start docker
sudo systemctl enable docker
```

### Port conflicts

Check what's using port 443:
```bash
sudo lsof -i :443
```

### SSL certificate issues

Renew certificates:
```bash
cd /opt/voyfy-vpn/docker/nginx/certbot
docker-compose run --rm certbot renew
```

## Environment Variables

Key variables in `/opt/voyfy-vpn/docker/.env`:

- `DB_USER`, `DB_PASSWORD` - PostgreSQL credentials
- `JWT_SECRET` - Secret for JWT tokens (change this!)
- `XRAY_PUBLIC_KEY`, `XRAY_PRIVATE_KEY` - Xray Reality keys
- `XRAY_SERVER_NAME` - SNI server name (e.g., www.microsoft.com)

## Support

For issues, check logs:
```bash
cd /opt/voyfy-vpn/docker
docker-compose logs
```

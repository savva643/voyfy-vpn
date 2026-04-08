# Voyfy VPN Server Setup Guide

Complete guide for deploying Voyfy VPN server with Docker on a VPS.

## Requirements

- **VPS**: Ubuntu 22.04 LTS (or Debian 11+)
- **RAM**: Minimum 1GB (2GB recommended)
- **Storage**: 20GB SSD minimum
- **Network**: Port 443 (TCP) open, located outside Russia for best connectivity
- **Domain** (optional): For SSL certificate with Nginx

## Table of Contents

1. [VPS Preparation](#1-vps-preparation)
2. [Docker Installation](#2-docker-installation)
3. [Project Setup](#3-project-setup)
4. [Xray Key Generation](#4-xray-key-generation)
5. [Configuration](#5-configuration)
6. [Deployment](#6-deployment)
7. [User Management](#7-user-management)
8. [Monitoring & Logs](#8-monitoring--logs)
9. [Troubleshooting](#9-troubleshooting)

---

## 1. VPS Preparation

### Update System

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl wget git nano ufw
```

### Configure Firewall

```bash
# Enable UFW
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow SSH (adjust port if needed)
sudo ufw allow 22/tcp

# Allow HTTP/HTTPS
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Allow API port (optional, if not using nginx)
sudo ufw allow 4000/tcp

# Enable firewall
sudo ufw enable
```

### Set Hostname (optional)

```bash
sudo hostnamectl set-hostname voyfy-vpn
```

---

## 2. Docker Installation

```bash
# Remove old versions
sudo apt remove docker docker-engine docker.io containerd runc

# Install prerequisites
sudo apt install -y ca-certificates gnupg lsb-release

# Add Docker's official GPG key
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Set up repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Add user to docker group
sudo usermod -aG docker $USER
newgrp docker

# Verify installation
docker --version
docker compose version
```

---

## 3. Project Setup

### Clone Repository

```bash
cd ~/
git clone https://github.com/yourusername/voyfy-vpn.git
cd voyfy-vpn
```

### Create Directory Structure

```bash
mkdir -p docker/xray docker/nginx backend/logs
```

---

## 4. Xray Key Generation

Generate X25519 keys for Xray Reality:

```bash
docker run --rm teddysun/xray xray x25519
```

Output example:
```
Private key: AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
Public key: BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB
```

**Save these keys!** You'll need them in the next step.

---

## 5. Configuration

### Create Environment File

```bash
cd docker
nano .env
```

Add the following (replace with your values):

```env
# Database
DB_USER=voyfy
DB_PASSWORD=your_secure_db_password_here
DB_NAME=voyfy_vpn

# JWT Secrets (generate strong random strings)
JWT_SECRET=$(openssl rand -hex 32)
JWT_REFRESH_SECRET=$(openssl rand -hex 32)

# Xray Configuration (use keys from step 4)
XRAY_PUBLIC_KEY=your_public_key_here
XRAY_PRIVATE_KEY=your_private_key_here

# Reality settings
XRAY_SERVER_NAME=www.microsoft.com
XRAY_SHORT_ID=$(openssl rand -hex 8)
XRAY_PORT=443

# Optional: External auth service
EXTERNAL_AUTH_ENABLED=false
AUTH_SERVICE_URL=https://auth.yourdomain.com
```

**Generate secure secrets:**
```bash
# JWT secrets
openssl rand -hex 32

# Short ID
openssl rand -hex 8
```

### SSL Certificates (for Nginx)

If using Nginx with HTTPS:

```bash
cd docker/nginx
mkdir -p ssl

# Generate self-signed certificate (for testing)
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout ssl/key.pem -out ssl/cert.pem \
  -subj "/C=US/ST=State/L=City/O=Organization/CN=your-domain.com"

# Or use Let's Encrypt (production)
# sudo apt install certbot
# sudo certbot certonly --standalone -d your-domain.com
# sudo cp /etc/letsencrypt/live/your-domain.com/fullchain.pem ssl/cert.pem
# sudo cp /etc/letsencrypt/live/your-domain.com/privkey.pem ssl/key.pem
```

### Configure Xray

The Xray configuration is generated dynamically from the template. The entrypoint script fetches user UUIDs from the API and builds the config.

Make entrypoint script executable:

```bash
chmod +x xray/entrypoint.sh
```

---

## 6. Deployment

### Start Services

```bash
cd docker

# Build and start
docker-compose up -d

# Or with Nginx (if configured)
docker-compose --profile with-nginx up -d
```

### Verify Deployment

```bash
# Check running containers
docker-compose ps

# Check logs
docker-compose logs -f api
docker-compose logs -f xray
docker-compose logs -f postgres

# Test API health
curl http://localhost:4000/api/health
```

Expected response:
```json
{
  "status": "ok",
  "service": "voyfy-backend",
  "version": "1.0.0"
}
```

---

## 7. User Management

### Create First Admin User

```bash
# Use curl or any API client
curl -X POST http://localhost:4000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "admin@voyfy.com",
    "password": "your_secure_password"
  }'
```

### Promote to Admin (Database)

```bash
# Access PostgreSQL
docker exec -it voyfy-postgres psql -U voyfy -d voyfy_vpn

# Make user admin
UPDATE users SET is_admin = true WHERE email = 'admin@voyfy.com';

# Exit
\q
```

### Add VPN Servers

As admin, add servers via API:

```bash
# Get token first
TOKEN=$(curl -s -X POST http://localhost:4000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@voyfy.com","password":"your_secure_password"}' \
  | jq -r '.data.tokens.accessToken')

# Add server
curl -X POST http://localhost:4000/api/admin/servers \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "name": "NYC-01",
    "country": "United States",
    "countryCode": "US",
    "host": "your-server-ip",
    "port": 443,
    "premium": false
  }'
```

### Python Script for Bulk User Creation

Create `scripts/add_users.py`:

```python
#!/usr/bin/env python3
"""Script to add users to Voyfy VPN"""
import requests
import uuid
import sys

API_URL = "http://localhost:4000"
ADMIN_TOKEN = "your_admin_token_here"

def create_user(email, password, admin=False):
    """Create a new user"""
    response = requests.post(
        f"{API_URL}/api/auth/register",
        json={"email": email, "password": password}
    )
    
    if response.status_code == 201:
        data = response.json()
        print(f"Created user: {email}")
        print(f"  UUID: {data['data']['uuid']}")
        print(f"  Subscription: {data['data']['subscriptionUrl']}")
        
        if admin:
            # Note: Requires admin to run SQL or API call
            print(f"  Run: UPDATE users SET is_admin = true WHERE email = '{email}';")
        
        return data['data']
    else:
        print(f"Failed to create {email}: {response.text}")
        return None

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python add_users.py <email> <password>")
        sys.exit(1)
    
    email = sys.argv[1]
    password = sys.argv[2]
    
    create_user(email, password)
```

Run:
```bash
python3 scripts/add_users.py user@example.com password123
```

---

## 8. Monitoring & Logs

### View Logs

```bash
cd docker

# All services
docker-compose logs -f

# Specific service
docker-compose logs -f api
docker-compose logs -f xray

# Last 100 lines
docker-compose logs --tail=100 xray
```

### Monitor Resources

```bash
# Container stats
docker stats

# System resources
htop
```

### Database Backup

```bash
# Backup
docker exec voyfy-postgres pg_dump -U voyfy voyfy_vpn > backup_$(date +%Y%m%d).sql

# Restore
cat backup_20240101.sql | docker exec -i voyfy-postgres psql -U voyfy -d voyfy_vpn
```

---

## 9. Troubleshooting

### Xray Won't Start

```bash
# Check config
docker-compose logs xray | head -50

# Validate config manually
docker run --rm -v $(pwd)/xray:/etc/xray teddysun/xray xray -test -config /etc/xray/config.json
```

### API Connection Issues

```bash
# Check if API is running
curl http://localhost:4000/api/health

# Check database connection
docker exec voyfy-api node -e "
const { Pool } = require('pg');
const pool = new Pool({
  host: 'postgres',
  user: 'voyfy',
  password: 'your_password',
  database: 'voyfy_vpn'
});
pool.query('SELECT NOW()', (err, res) => {
  console.log(err || res.rows[0]);
  pool.end();
});
"
```

### Reset Everything

```bash
cd docker

# Stop and remove everything
docker-compose down -v

# Remove images (optional)
docker rmi voyfy-api teddysun/xray

# Recreate
docker-compose up -d
```

### Port Already in Use

```bash
# Find process using port 443
sudo lsof -i :443

# Kill process or change XRAY_PORT in .env
```

### Connection Issues from Client

1. Check firewall:
```bash
sudo ufw status
sudo iptables -L -n | grep 443
```

2. Verify Xray is listening:
```bash
sudo netstat -tlnp | grep 443
# or
sudo ss -tlnp | grep 443
```

3. Test with telnet:
```bash
telnet your-server-ip 443
```

---

## Advanced Configuration

### Multiple Server Locations

For multiple VPS locations:

1. Deploy API + Postgres on main server
2. Deploy Xray-only on other locations
3. Update database with new server entries

### Custom Routing Rules

Modify Xray config template in `docker/xray/config.json.template`:

```json
{
  "routing": {
    "rules": [
      {
        "type": "field",
        "domain": ["geosite:category-ads"],
        "outboundTag": "block"
      },
      {
        "type": "field",
        "ip": ["geoip:private", "geoip:cn"],
        "outboundTag": "direct"
      }
    ]
  }
}
```

### Auto SSL with Let's Encrypt

```bash
# Install certbot
sudo apt install certbot

# Obtain certificate
sudo certbot certonly --standalone -d vpn.yourdomain.com

# Auto-renewal cron
sudo crontab -e
# Add: 0 12 * * * /usr/bin/certbot renew --quiet
```

---

## Security Checklist

- [ ] Change default database password
- [ ] Use strong JWT secrets
- [ ] Keep Xray private key secret
- [ ] Enable UFW firewall
- [ ] Use SSL/TLS certificates
- [ ] Regular updates: `sudo apt update && sudo apt upgrade`
- [ ] Database backups configured
- [ ] Log rotation configured

---

## Support

For issues and questions:
- Check logs: `docker-compose logs`
- API docs: `http://your-server:4000/api/health`
- Test connectivity: `curl -v telnet://your-ip:443`

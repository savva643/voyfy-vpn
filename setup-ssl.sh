#!/bin/bash

# Voyfy VPN SSL Setup Script
# This script sets up SSL certificates for vip.necsoura.ru and 185.164.163.166

set -e

DOMAIN="vip.necsoura.ru"
IP="185.164.163.166"
EMAIL="admin@${DOMAIN}"

echo "======================================"
echo "Voyfy VPN SSL Setup"
echo "======================================"
echo "Domain: $DOMAIN"
echo "IP: $IP"
echo "Email: $EMAIL"
echo "======================================"

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root (sudo)"
    exit 1
fi

# Install certbot if not installed
if ! command -v certbot &> /dev/null; then
    echo "Installing certbot..."
    apt update
    apt install -y certbot python3-certbot-nginx
fi

# Stop nginx to use standalone mode
echo "Stopping nginx..."
systemctl stop nginx

# Create directory for ACME challenge
mkdir -p /var/www/certbot

# Obtain SSL certificate for domain
echo "Obtaining SSL certificate for $DOMAIN..."
certbot certonly --standalone \
    -d "$DOMAIN" \
    -d "$IP" \
    --email "$EMAIL" \
    --agree-tos \
    --non-interactive

# Test auto-renewal
echo "Testing auto-renewal..."
certbot renew --dry-run

# Start nginx
echo "Starting nginx..."
systemctl start nginx

# Setup auto-renewal cron job
echo "Setting up auto-renewal cron job..."
(crontab -l 2>/dev/null; echo "0 0 * * * certbot renew --quiet --post-hook 'systemctl reload nginx'") | crontab -

echo "======================================"
echo "SSL Setup Complete!"
echo "======================================"
echo "Certificate location: /etc/letsencrypt/live/$DOMAIN/"
echo "Auto-renewal: Enabled (daily at midnight)"
echo "======================================"

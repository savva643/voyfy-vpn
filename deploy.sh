#!/bin/bash

# Voyfy VPN Docker Deployment Script
# Run this on your VPS

set -e

echo "======================================"
echo "Voyfy VPN Docker Deployment"
echo "======================================"

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root (sudo)"
    exit 1
fi

# Auto-detect server IP
IP=$(hostname -I | awk '{print $1}')
if [ -z "$IP" ]; then
    IP=$(ip route get 1.1.1.1 2>/dev/null | grep -oP 'src \K[\d.]+')
fi
if [ -z "$IP" ]; then
    IP=$(curl -s ifconfig.me 2>/dev/null || curl -s icanhazip.com 2>/dev/null)
fi

# Configuration
DOMAIN="vip.necsoura.ru"
PROJECT_DIR="/opt/voyfy-vpn"
DOCKER_DIR="$PROJECT_DIR/docker"

# Check if running from project directory
if [ -f "$(pwd)/deploy.sh" ]; then
    PROJECT_DIR="$(pwd)"
    DOCKER_DIR="$PROJECT_DIR/docker"
    echo "Running from existing project directory: $PROJECT_DIR"
fi

echo "Domain: $DOMAIN"
echo "IP: $IP"
echo "Project directory: $PROJECT_DIR"
echo "======================================"

# Parse command line arguments
SKIP_UPDATE=false
SKIP_DOCKER=false
SKIP_SSL=false
SKIP_FIREWALL=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-update) SKIP_UPDATE=true ;;
        --skip-docker) SKIP_DOCKER=true ;;
        --skip-ssl) SKIP_SSL=true ;;
        --skip-firewall) SKIP_FIREWALL=true ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --skip-update    Skip system update"
            echo "  --skip-docker    Skip Docker installation"
            echo "  --skip-ssl       Skip SSL certificate setup"
            echo "  --skip-firewall  Skip firewall configuration"
            echo "  --help           Show this help"
            exit 0
            ;;
    esac
    shift
done

# Step 1: Update system
if [ "$SKIP_UPDATE" = false ]; then
    echo "Step 1: Updating system..."
    apt update && apt upgrade -y
else
    echo "Step 1: Skipping system update..."
fi

# Step 2: Install Docker and dependencies
if [ "$SKIP_DOCKER" = false ]; then
    echo "Step 2: Installing Docker and dependencies..."
    apt install -y curl git ufw unzip

    # Remove old Docker versions if present
    apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

    # Install Docker
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh

    # Install Docker Compose plugin
    apt install -y docker-compose-plugin

    # Add current user to docker group (if not root)
    if [ -n "$SUDO_USER" ]; then
        usermod -aG docker $SUDO_USER
    fi

    # Enable and start Docker
    systemctl enable docker
    systemctl start docker
else
    echo "Step 2: Skipping Docker installation..."
fi

# Verify Docker is installed
if ! command -v docker &> /dev/null; then
    echo "ERROR: Docker is not installed!"
    exit 1
fi

echo "Docker version: $(docker --version)"
echo "Docker Compose version: $(docker compose version)"

# Step 3: Clone repository
echo "Step 3: Checking repository..."
if [ -d "$PROJECT_DIR" ]; then
    echo "Repository already exists at $PROJECT_DIR"
    cd "$PROJECT_DIR"
    echo "Pulling latest changes..."
    git pull || echo "Git pull failed, continuing anyway"
else
    echo "Cloning repository to $PROJECT_DIR..."
    mkdir -p "$(dirname "$PROJECT_DIR")"
    git clone https://github.com/savva643/voyfy-vpn.git "$PROJECT_DIR"
    cd "$PROJECT_DIR"
fi

# Step 4: Generate secrets
echo "Step 4: Generating secrets..."
DB_PASSWORD=$(openssl rand -base64 32)
JWT_SECRET=$(openssl rand -hex 32)
JWT_REFRESH_SECRET=$(openssl rand -hex 32)
ADMIN_API_KEY=$(openssl rand -hex 32)

# Generate Xray keys
echo "Generating Xray keys..."
XRAY_KEYS=$(docker run --rm teddysun/xray xray x25519)
XRAY_PRIVATE_KEY=$(echo "$XRAY_KEYS" | grep "Private key:" | awk '{print $3}')
XRAY_PUBLIC_KEY=$(echo "$XRAY_KEYS" | grep "Public key:" | awk '{print $3}')
XRAY_SHORT_ID=$(openssl rand -hex 8)

# Fallback if keys are empty
if [ -z "$XRAY_PRIVATE_KEY" ] || [ -z "$XRAY_PUBLIC_KEY" ]; then
    echo "WARNING: Xray key generation failed, using fallback method"
    XRAY_PRIVATE_KEY=$(docker run --rm teddysun/xray xray x25519 | tail -1)
    XRAY_PUBLIC_KEY=$(docker run --rm teddysun/xray xray x25519 | tail -1)
fi

echo "XRAY Public Key: $XRAY_PUBLIC_KEY"
echo "XRAY Private Key: $XRAY_PRIVATE_KEY"
echo "XRAY Short ID: $XRAY_SHORT_ID"

# Step 4.5: Download Xray binaries for client distribution
if [ "$SKIP_XRAY_DOWNLOAD" != true ]; then
    echo "Step 4.5: Downloading Xray binaries for clients..."
    
    XRAY_BINARIES_DIR="$PROJECT_DIR/backend/src/xray-binaries"
    mkdir -p "$XRAY_BINARIES_DIR"
    cd "$XRAY_BINARIES_DIR"
    
    # Function to download and extract Xray
    download_xray() {
        local platform=$1
        local arch=$2
        local filename=$3
        local asset_name=$4
        local url="https://github.com/XTLS/Xray-core/releases/latest/download/${asset_name}"
        
        echo "Downloading Xray for ${platform}-${arch}..."
        
        if [ -f "$filename" ]; then
            echo "  ${filename} already exists, skipping..."
            return 0
        fi
        
        echo "  URL: $url"
        
        # Download with verbose output for debugging
        if ! wget --show-progress "$url" -O "temp_${platform}_${arch}.zip" 2>&1; then
            echo "  wget failed, trying curl..."
            if ! curl -L --progress-bar -o "temp_${platform}_${arch}.zip" "$url" 2>&1; then
                echo "  ERROR: Could not download ${platform}-${arch}"
                return 1
            fi
        fi
        
        # Check if file was downloaded and has content
        if [ ! -s "temp_${platform}_${arch}.zip" ]; then
            echo "  ERROR: Downloaded file is empty"
            rm -f "temp_${platform}_${arch}.zip"
            return 1
        fi
        
        echo "  File downloaded, size: $(ls -lh temp_${platform}_${arch}.zip | awk '{print $5}')"
        
        # Extract with error output
        if ! unzip -o "temp_${platform}_${arch}.zip" 2>&1; then
            echo "  ERROR: Failed to extract ${platform}-${arch}"
            echo "  File type: $(file temp_${platform}_${arch}.zip)"
            rm -f "temp_${platform}_${arch}.zip"
            return 1
        fi
        
        # Find and rename the binary
        if [ -f "xray.exe" ]; then
            mv xray.exe "$filename"
            echo "  Found xray.exe, renamed to $filename"
        elif [ -f "xray" ]; then
            mv xray "$filename"
            chmod +x "$filename"
            echo "  Found xray, renamed to $filename"
        else
            echo "  ERROR: Neither xray.exe nor xray found after extraction"
            ls -la
            return 1
        fi
        
        # Cleanup
        rm -f "temp_${platform}_${arch}.zip"
        rm -f geoip.dat geosite.dat 2>/dev/null
        rm -f *.zip 2>/dev/null
        rm -f README.md LICENSE 2>/dev/null
        
        if [ -f "$filename" ]; then
            echo "  ${filename} downloaded successfully"
            ls -lh "$filename"
        else
            echo "  ERROR: ${filename} not found after extraction"
            return 1
        fi
    }
    
    # Download all platforms with correct asset names
    # Windows uses amd64 not 64
    download_xray "windows" "64" "xray-windows-64.exe" "Xray-windows-64.zip" || \
        download_xray "windows" "64" "xray-windows-64.exe" "Xray-windows-amd64.zip" || \
        echo "  Windows 64-bit download failed, will skip..."
    
    download_xray "windows" "arm64" "xray-windows-arm64.exe" "Xray-windows-arm64.zip" || \
        echo "  Windows ARM64 not available, skipping..."
    
    download_xray "linux" "64" "xray-linux-64" "Xray-linux-64.zip" || \
        download_xray "linux" "64" "xray-linux-64" "Xray-linux-amd64.zip" || \
        echo "  Linux 64-bit download failed..."
    
    download_xray "linux" "arm64" "xray-linux-arm64" "Xray-linux-arm64.zip" || \
        download_xray "linux" "arm64-v8a" "xray-linux-arm64-v8a" "Xray-linux-arm64-v8a.zip" || \
        echo "  Linux ARM64 not available, skipping..."
    download_xray "macos" "64" "xray-darwin-64" "Xray-darwin-64.zip"
    download_xray "macos" "arm64-v8a" "xray-darwin-arm64" "Xray-darwin-arm64.zip" || \
        download_xray "macos" "arm64" "xray-darwin-arm64" "Xray-darwin-arm64.zip"
    
    echo "Xray binaries download complete!"
    echo "Available binaries:"
    ls -lh "$XRAY_BINARIES_DIR/"
    
    cd "$PROJECT_DIR"
else
    echo "Step 4.5: Skipping Xray download (SKIP_XRAY_DOWNLOAD=true)"
fi

# Step 5: Create .env file for Docker
echo "Step 5: Creating .env file..."
cd docker
cat > .env <<EOF
# Database Configuration
DB_USER=voyfy
DB_PASSWORD=$DB_PASSWORD
DB_NAME=voyfy_vpn

# JWT Configuration
JWT_SECRET=$JWT_SECRET
JWT_REFRESH_SECRET=$JWT_REFRESH_SECRET

# Xray Configuration
XRAY_PUBLIC_KEY=$XRAY_PUBLIC_KEY
XRAY_PRIVATE_KEY=$XRAY_PRIVATE_KEY
XRAY_SERVER_NAME=www.microsoft.com
XRAY_SHORT_ID=$XRAY_SHORT_ID
XRAY_PORT=8443
XRAY_API_PORT=10085

# Admin API Key
ADMIN_API_KEY=$ADMIN_API_KEY
EOF

echo "Docker .env created"

# Step 6: Setup SSL certificates
if [ "$SKIP_SSL" = false ]; then
    echo "Step 6: Setting up SSL certificates..."

    # Check if certificate already exists
    if [ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]; then
        echo "SSL certificate already exists for $DOMAIN, skipping..."
    else
        apt install -y certbot

        # Stop nginx if running to free port 80
        systemctl stop nginx 2>/dev/null || true
        docker compose -f "$DOCKER_DIR/docker-compose.yml" down nginx 2>/dev/null || true

        # Get SSL certificate
        echo "Requesting SSL certificate for $DOMAIN..."
        certbot certonly --standalone \
            -d "$DOMAIN" \
            --email "admin@$DOMAIN" \
            --agree-tos \
            --non-interactive || {
            echo "WARNING: SSL certificate failed to obtain. Continuing without SSL..."
            echo "You can configure SSL later manually."
        }

        # Setup auto-renewal
        (crontab -l 2>/dev/null; echo "0 0 * * * certbot renew --quiet") | crontab -
    fi
else
    echo "Step 6: Skipping SSL certificate setup..."
fi

# Step 7: Update Nginx config for Docker
echo "Step 7: Updating Nginx configuration..."
mkdir -p $DOCKER_DIR/nginx/ssl

# Copy SSL certificates to docker directory (only if they exist)
if [ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]; then
    cp /etc/letsencrypt/live/$DOMAIN/fullchain.pem $DOCKER_DIR/nginx/ssl/
    cp /etc/letsencrypt/live/$DOMAIN/privkey.pem $DOCKER_DIR/nginx/ssl/
    chown -R 1000:1000 $DOCKER_DIR/nginx/ssl
    USE_SSL=true
else
    echo "No SSL certificates found, using HTTP only..."
    USE_SSL=false
fi

# Create HTTPS nginx config for Docker (only if SSL available)
if [ "$USE_SSL" = true ]; then
    cat > $DOCKER_DIR/nginx/nginx-https.conf <<'EOF'
events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';

    access_log /var/log/nginx/access.log main;
    error_log /var/log/nginx/error.log warn;

    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;

    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types text/plain text/css text/xml application/json application/javascript application/rss+xml application/atom+xml image/svg+xml;

    upstream api_backend {
        server api:4000;
        keepalive 32;
    }

    server {
        listen 80;
        server_name vip.necsoura.ru 185.164.163.166;
        return 301 https://$host$request_uri;
    }

    server {
        listen 443 ssl http2;
        server_name vip.necsoura.ru 185.164.163.166;

        ssl_certificate /etc/nginx/ssl/fullchain.pem;
        ssl_certificate_key /etc/nginx/ssl/privkey.pem;

        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384;
        ssl_prefer_server_ciphers off;
        ssl_session_cache shared:SSL:10m;
        ssl_session_timeout 10m;

        add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-Content-Type-Options "nosniff" always;

        location /api/ {
            proxy_pass http://api_backend;
            proxy_http_version 1.1;
            proxy_set_header Connection "";
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;

            proxy_connect_timeout 60s;
            proxy_send_timeout 60s;
            proxy_read_timeout 60s;
        }

        location /admin {
            proxy_pass http://api_backend;
            proxy_http_version 1.1;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;

            proxy_connect_timeout 60s;
            proxy_send_timeout 60s;
            proxy_read_timeout 60s;
        }

        location /health {
            proxy_pass http://api_backend/api/health;
            access_log off;
        }

        # VPN server installation scripts
        location /vpn-server/ {
            alias /usr/share/nginx/vpn-server/;
            autoindex off;
            types {
                application/x-sh sh;
            }
            default_type application/x-sh;
        }

        location / {
            root /usr/share/nginx/html;
            index index.html;
            try_files $uri $uri/ /index.html;

            location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2)$ {
                expires 1y;
                add_header Cache-Control "public, immutable";
            }
        }
    }
}
EOF

    # Update docker-compose.yml to use HTTPS nginx
    sed -i 's|nginx-http.conf|nginx-https.conf|g' $DOCKER_DIR/docker-compose.yml
    echo "Using HTTPS nginx configuration"
else
    echo "Using HTTP nginx configuration (no SSL)"
fi

# Step 8: Build and start Docker containers
echo "Step 8: Building and starting Docker containers..."
cd $DOCKER_DIR

# Build images
docker compose build

# Start containers
docker compose up -d

# Wait for services to be ready
echo "Waiting for services to start..."
sleep 10

# Check status
docker compose ps

# Step 9: Configure Firewall
if [ "$SKIP_FIREWALL" = false ]; then
    echo "Step 9: Configuring firewall..."

# Reset UFW to default state
ufw --force reset

# Set default policies
ufw default deny incoming
ufw default allow outgoing

# Allow SSH (CRITICAL - do this FIRST)
ufw allow 22/tcp
ufw allow 22/udp

# Allow current SSH connection to prevent lockout
CURRENT_IP=$(echo $SSH_CLIENT | awk '{print $1}')
if [ -n "$CURRENT_IP" ]; then
    echo "Allowing SSH from current IP: $CURRENT_IP"
    ufw allow from $CURRENT_IP to any port 22
fi

# Allow HTTP/HTTPS
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 443/udp

# Allow VPN port
ufw allow 8443/tcp
ufw allow 8443/udp

# Show rules before enabling
echo "Firewall rules:"
ufw show added

# Enable firewall
ufw --force enable

echo "Firewall status:"
ufw status verbose
else
    echo "Step 9: Skipping firewall configuration..."
fi

# Step 10: Setup SSL auto-renewal hook
echo "Step 10: Setting up SSL auto-renewal..."
cat > /etc/letsencrypt/renewal-hooks/post/docker-nginx-reload.sh <<'EOF'
#!/bin/bash
# Copy renewed certificates to Docker nginx
cp /etc/letsencrypt/live/vip.necsoura.ru/fullchain.pem /var/www/voyfy-vpn/docker/nginx/ssl/
cp /etc/letsencrypt/live/vip.necsoura.ru/privkey.pem /var/www/voyfy-vpn/docker/nginx/ssl/
chown -R 1000:1000 /var/www/voyfy-vpn/docker/nginx/ssl
docker compose -f /var/www/voyfy-vpn/docker/docker-compose.yml restart nginx
EOF

chmod +x /etc/letsencrypt/renewal-hooks/post/docker-nginx-reload.sh

echo "======================================"
echo "Deployment Complete!"
echo "======================================"
if [ "$USE_SSL" = true ]; then
    PROTOCOL="https"
else
    PROTOCOL="http"
fi
echo "Frontend: $PROTOCOL://$DOMAIN"
echo "Admin Panel: $PROTOCOL://$DOMAIN/admin"
echo "API: $PROTOCOL://$DOMAIN/api"
echo "Health Check: $PROTOCOL://$DOMAIN/health"
echo "======================================"
echo "IMPORTANT: Save these credentials!"
echo "======================================"
echo "Database Password: $DB_PASSWORD"
echo "JWT Secret: $JWT_SECRET"
echo "JWT Refresh Secret: $JWT_REFRESH_SECRET"
echo "Admin API Key: $ADMIN_API_KEY"
echo "XRAY Private Key: $XRAY_PRIVATE_KEY"
echo "XRAY Public Key: $XRAY_PUBLIC_KEY"
echo "XRAY Short ID: $XRAY_SHORT_ID"
echo "======================================"
echo "Next steps:"
echo "1. Open https://$DOMAIN/admin"
echo "2. Register first user"
echo "3. Make user admin in database"
echo "4. Create pairing code for VPN server"
echo "======================================"

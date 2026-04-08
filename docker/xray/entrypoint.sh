#!/bin/sh

# Xray configuration entrypoint
# Generates config from environment variables

set -e

API_BASE_URL="${API_BASE_URL:-http://api:4000}"
XRAY_PORT="${XRAY_PORT:-443}"
SERVER_NAME="${XRAY_SERVER_NAME:-www.microsoft.com}"
SERVER_NAME_ALT="${XRAY_SERVER_NAME_ALT:-microsoft.com}"
PRIVATE_KEY="${XRAY_PRIVATE_KEY}"
PUBLIC_KEY="${XRAY_PUBLIC_KEY}"
SHORT_ID="${XRAY_SHORT_ID:-0123456789abcdef}"
CONFIG_FILE="/etc/xray/config.json"

echo "=== Voyfy Xray Server Configuration ==="
echo "API URL: $API_BASE_URL"
echo "Port: $XRAY_PORT"
echo "Server Name: $SERVER_NAME"
echo "Short ID: $SHORT_ID"

# Use default test keys if not provided (FOR TESTING ONLY - generate real keys for production)
DEFAULT_PRIVATE_KEY="8J-9gP62QbCN7lGnsz7S3z5zS3z5zS3z5zS3z5zS3z0"
DEFAULT_PUBLIC_KEY="BD0r53UJYzACpGv9MDF3H9lmcvJVZXP0wF5QmPJVZXP0"

if [ -z "$PRIVATE_KEY" ]; then
    echo "WARNING: XRAY_PRIVATE_KEY not set, using default test key!"
    PRIVATE_KEY="$DEFAULT_PRIVATE_KEY"
fi

if [ -z "$PUBLIC_KEY" ]; then
    echo "WARNING: XRAY_PUBLIC_KEY not set, using default test key!"
    PUBLIC_KEY="$DEFAULT_PUBLIC_KEY"
fi

# Generate config file
echo "Building Xray configuration..."

cat > "$CONFIG_FILE" << 'EOF'
{
  "log": {
    "loglevel": "warning",
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log"
  },
  "inbounds": [
    {
      "port": PORT_PLACEHOLDER,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "550e8400-e29b-41d4-a716-446655440000",
            "flow": "xtls-rprx-vision",
            "email": "default@voyfy.com"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "dest": "DEST_PLACEHOLDER:443",
          "xver": 0,
          "serverNames": [
            "SERVER_PLACEHOLDER",
            "SERVER_ALT_PLACEHOLDER"
          ],
          "privateKey": "PRIVATE_KEY_PLACEHOLDER",
          "publicKey": "PUBLIC_KEY_PLACEHOLDER",
          "shortIds": [
            "SHORT_ID_PLACEHOLDER"
          ]
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls", "quic"]
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "direct"
    },
    {
      "protocol": "blackhole",
      "tag": "block"
    }
  ],
  "routing": {
    "rules": [
      {
        "type": "field",
        "ip": ["geoip:private"],
        "outboundTag": "block"
      }
    ]
  }
}
EOF

# Replace placeholders with actual values
sed -i "s/PORT_PLACEHOLDER/$XRAY_PORT/g" "$CONFIG_FILE"
sed -i "s/DEST_PLACEHOLDER/$SERVER_NAME/g" "$CONFIG_FILE"
sed -i "s/SERVER_PLACEHOLDER/$SERVER_NAME/g" "$CONFIG_FILE"
sed -i "s/SERVER_ALT_PLACEHOLDER/$SERVER_NAME_ALT/g" "$CONFIG_FILE"
# Use # delimiter for keys to avoid issues with special characters
sed -i "s#PRIVATE_KEY_PLACEHOLDER#$PRIVATE_KEY#g" "$CONFIG_FILE"
sed -i "s#PUBLIC_KEY_PLACEHOLDER#$PUBLIC_KEY#g" "$CONFIG_FILE"
sed -i "s/SHORT_ID_PLACEHOLDER/$SHORT_ID/g" "$CONFIG_FILE"

echo "Configuration written to $CONFIG_FILE"

# Validate configuration
echo "Validating Xray configuration..."
if /usr/bin/xray -test -config "$CONFIG_FILE"; then
    echo "Configuration is valid!"
else
    echo "ERROR: Invalid configuration"
    exit 1
fi

# Create log directories
mkdir -p /var/log/xray
touch /var/log/xray/access.log /var/log/xray/error.log

# Start Xray
echo "=== Starting Xray Server ==="
exec /usr/bin/xray -config "$CONFIG_FILE"

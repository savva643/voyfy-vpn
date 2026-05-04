#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PAIRING_CODE="${1:-}"
API_ENDPOINT="${API_ENDPOINT:-https://vip.necsoura.ru}"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  VoyFy VPN Server Installer${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}❌ Запустите от root${NC}"
   exit 1
fi

if [[ -z "$PAIRING_CODE" ]]; then
    echo -e "${RED}❌ Не указан код привязки${NC}"
    echo "  curl -fsSL https://vip.necsoura.ru/vpn-server/install.sh | bash -s -- \"VOYFY-XXXXXX\""
    exit 1
fi

# Verify pairing code
echo -e "${YELLOW}🔐 Проверка кода...${NC}"
VERIFY=$(curl -s -X POST "$API_ENDPOINT/api/servers/verify-code" \
    -H "Content-Type: application/json" \
    -d "{\"code\": \"$PAIRING_CODE\"}")

if ! echo "$VERIFY" | jq -e '.success' >/dev/null 2>&1; then
    echo -e "${RED}❌ Неверный код${NC}"
    exit 1
fi

SERVER_NAME=$(echo "$VERIFY" | jq -r '.serverName')
SERVER_COUNTRY=$(echo "$VERIFY" | jq -r '.country')
SERVER_COUNTRY_CODE=$(echo "$VERIFY" | jq -r '.countryCode')
SERVER_PREMIUM=$(echo "$VERIFY" | jq -r '.premium')

echo -e "${GREEN}✅ Код верифицирован: $SERVER_NAME${NC}"

# Установка
apt-get update -qq
apt-get install -y -qq curl wget jq uuid-runtime ufw bc openssl

# Фаервол
ufw default deny incoming >/dev/null 2>&1
ufw default allow outgoing >/dev/null 2>&1
ufw allow 22/tcp >/dev/null 2>&1
ufw allow 8444/tcp >/dev/null 2>&1
ufw --force enable >/dev/null 2>&1

# XRay
echo -e "${YELLOW}🔧 Установка XRay...${NC}"
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install >/dev/null 2>&1

# Генерация ключей (ИСПРАВЛЕННАЯ ВЕРСИЯ)
echo -e "${YELLOW}🔐 Генерация ключей...${NC}"
KEYS=$(/usr/local/bin/xray x25519 2>/dev/null)

# Парсим ключи Xray v26.3.27
PRIVATE_KEY=$(echo "$KEYS" | grep "PrivateKey:" | sed 's/PrivateKey: //' | tr -d ' ')
PUBLIC_KEY=$(echo "$KEYS" | grep "Password (PublicKey):" | sed 's/Password (PublicKey): //' | tr -d ' ')
SHORT_ID=$(openssl rand -hex 4)

# IP адрес с fallback (принудительно IPv4)
SERVER_IP=$(curl -s --max-time 10 -4 ifconfig.me)
if [ -z "$SERVER_IP" ]; then
    SERVER_IP=$(curl -s --max-time 10 -4 icanhazip.com)
fi
if [ -z "$SERVER_IP" ]; then
    SERVER_IP=$(hostname -I | tr ' ' '\n' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -1)
fi

if [ -z "$SERVER_IP" ] || [ -z "$PRIVATE_KEY" ] || [ -z "$PUBLIC_KEY" ]; then
    echo -e "${RED}❌ Ошибка получения IP или ключей${NC}"
    exit 1
fi

echo "  IP: $SERVER_IP"
echo "  Keys: OK"

# Конфигурация XRay
mkdir -p /usr/local/etc/xray /var/log/xray
cat > /usr/local/etc/xray/config.json <<XRAYEOF
{
  "log": {"loglevel": "warning", "access": "/var/log/xray/access.log", "error": "/var/log/xray/error.log"},
  "inbounds": [{
    "port": 8444, "protocol": "vless",
    "settings": {"clients": [], "decryption": "none"},
    "streamSettings": {
      "network": "tcp", "security": "reality",
      "realitySettings": {
        "show": false, "dest": "${SERVER_NAME:-vip.necsoura.ru}:443", "xver": 0,
        "serverNames": ["${SERVER_NAME:-vip.necsoura.ru}"],
        "privateKey": "$PRIVATE_KEY", "shortIds": ["", "$SHORT_ID"]
      }
    },
    "sniffing": {"enabled": true, "destOverride": ["http", "tls", "quic"]}
  }],
  "outbounds": [
    {"protocol": "freedom", "tag": "direct"},
    {"protocol": "blackhole", "tag": "block"}
  ]
}
XRAYEOF

# Сервис XRay
cat > /etc/systemd/system/xray.service <<EOF
[Unit]
Description=XRay Service
After=network.target

[Service]
User=root
ExecStart=/usr/local/bin/xray run -config /usr/local/etc/xray/config.json
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable xray
systemctl start xray

# Регистрация
echo -e "${YELLOW}🌐 Регистрация в API...${NC}"

RESPONSE=$(curl -s -X POST "$API_ENDPOINT/api/servers/register" \
    -H "Content-Type: application/json" \
    -d "{
      \"pairingCode\": \"$PAIRING_CODE\",
      \"name\": \"$SERVER_NAME\",
      \"country\": \"$SERVER_COUNTRY\",
      \"countryCode\": \"$SERVER_COUNTRY_CODE\",
      \"host\": \"$SERVER_IP\",
      \"port\": 8444,
      \"publicKey\": \"$PUBLIC_KEY\",
      \"serverNames\": [\"www.google.com\", \"www.youtube.com\"],
      \"shortId\": \"$SHORT_ID\",
      \"premium\": $SERVER_PREMIUM
    }")

if echo "$RESPONSE" | jq -e '.success' >/dev/null 2>&1; then
    SERVER_ID=$(echo "$RESPONSE" | jq -r '.serverId')
    API_KEY=$(echo "$RESPONSE" | jq -r '.apiKey')
    echo -e "${GREEN}✅ Сервер зарегистрирован: $SERVER_ID${NC}"
    
    # Конфиг и heartbeat
    VOYFY_DIR="/opt/voyfy-vpn/vpn-server"
    mkdir -p "$VOYFY_DIR"
    echo "{\"serverId\": \"$SERVER_ID\", \"apiKey\": \"$API_KEY\", \"api\": {\"endpoint\": \"$API_ENDPOINT\"}}" > "$VOYFY_DIR/config.json"

    # Скачать heartbeat если доступен
    curl -fsSL "$API_ENDPOINT/vpn-server/heartbeat.sh" -o "$VOYFY_DIR/heartbeat.sh" 2>/dev/null && chmod +x "$VOYFY_DIR/heartbeat.sh"

    # Сервис heartbeat
    cat > /etc/systemd/system/voyfy-heartbeat.service <<EOF
[Unit]
Description=VoyFy Heartbeat
After=network.target

[Service]
Type=simple
ExecStart=/bin/bash $VOYFY_DIR/heartbeat.sh
Restart=always
RestartSec=60
User=root

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable voyfy-heartbeat 2>/dev/null || true
    systemctl start voyfy-heartbeat 2>/dev/null || true
    
    echo -e "${GREEN}✅ VPN Сервер готов!${NC}"
else
    echo -e "${RED}❌ Ошибка регистрации: $(echo "$RESPONSE" | jq -r '.message')${NC}"
    exit 1
fi
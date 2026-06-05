#!/bin/bash
#
# Hysteria2 VPN Server Installation Script
# For Russia whitelist bypass (June 2025)
# Replaces Xray Reality with Hysteria2 (QUIC protocol)
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PAIRING_CODE="${1:-}"
API_ENDPOINT="${API_ENDPOINT:-https://vip.necsoura.ru}"
HYSTERIA_VERSION="v2.5.1"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  VoyFy VPN Server Installer (Hysteria2)${NC}"
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

# Удаление старого Xray если есть
echo -e "${YELLOW}🧹 Очистка старого XRay...${NC}"
systemctl stop xray 2>/dev/null || true
systemctl disable xray 2>/dev/null || true
rm -f /usr/local/bin/xray 2>/dev/null || true
rm -rf /usr/local/etc/xray 2>/dev/null || true
rm -f /etc/systemd/system/xray.service 2>/dev/null || true

# Удаление старого Hysteria если есть
systemctl stop hysteria-server 2>/dev/null || true
systemctl disable hysteria-server 2>/dev/null || true
rm -f /usr/local/bin/hysteria 2>/dev/null || true
rm -rf /etc/hysteria 2>/dev/null || true
rm -f /etc/systemd/system/hysteria-server.service 2>/dev/null || true
systemctl daemon-reload 2>/dev/null || true

# Фаервол
ufw default deny incoming >/dev/null 2>&1
ufw default allow outgoing >/dev/null 2>&1
ufw allow 22/tcp >/dev/null 2>&1
ufw allow 8444/udp >/dev/null 2>&1
ufw allow 8444/tcp >/dev/null 2>&1
ufw --force enable >/dev/null 2>&1

# Hysteria2
echo -e "${YELLOW}🔧 Установка Hysteria2 ${HYSTERIA_VERSION}...${NC}"
ARCH=$(uname -m)
case $ARCH in
    x86_64) HYSTERIA_ARCH="amd64" ;;
    aarch64) HYSTERIA_ARCH="arm64" ;;
    armv7l) HYSTERIA_ARCH="armv7" ;;
    *) echo -e "${RED}❌ Неизвестная архитектура: $ARCH${NC}"; exit 1 ;;
esac

wget -q -O /usr/local/bin/hysteria "https://github.com/apernet/hysteria/releases/download/app/${HYSTERIA_VERSION}/hysteria-linux-${HYSTERIA_ARCH}"
chmod +x /usr/local/bin/hysteria

# Генерация пароля
echo -e "${YELLOW}🔐 Генерация пароля...${NC}"
HYSTERIA_PASSWORD=$(openssl rand -base64 32)
OBFS_PASSWORD=$(openssl rand -hex 16)

# IP адрес с fallback (принудительно IPv4)
SERVER_IP=$(curl -s --max-time 10 -4 ifconfig.me)
if [ -z "$SERVER_IP" ]; then
    SERVER_IP=$(curl -s --max-time 10 -4 icanhazip.com)
fi
if [ -z "$SERVER_IP" ]; then
    SERVER_IP=$(hostname -I | tr ' ' '\n' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -1)
fi

if [ -z "$SERVER_IP" ]; then
    echo -e "${RED}❌ Ошибка получения IP${NC}"
    exit 1
fi

echo "  IP: $SERVER_IP"
echo "  Password: OK"
echo "  Obfs: OK"

# Конфигурация Hysteria2
mkdir -p /etc/hysteria /var/log/hysteria
cat > /etc/hysteria/config.yaml <<HYSTERIAEOF
listen: :8444
tls:
  cert: /etc/hysteria/server.crt
  key: /etc/hysteria/server.key
auth:
  type: password
  password: "$HYSTERIA_PASSWORD"
obfs:
  type: salamander
  salamander:
    password: "$OBFS_PASSWORD"
masquerade:
  type: proxy
  proxy:
    url: https://www.gosuslugi.ru
    rewriteHost: true
quic:
  initStreamReceiveWindow: 8388608
  maxStreamReceiveWindow: 8388608
  initConnReceiveWindow: 20971520
  maxConnReceiveWindow: 20971520
HYSTERIAEOF

# Генерация самоподписанных сертификатов
openssl req -x509 -newkey rsa:4096 -keyout /etc/hysteria/server.key -out /etc/hysteria/server.crt -days 365 -nodes -subj "/CN=voyfy-vpn" 2>/dev/null

# Сервис Hysteria2
cat > /etc/systemd/system/hysteria-server.service <<EOF
[Unit]
Description=Hysteria2 Server Service
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/hysteria server -c /etc/hysteria/config.yaml
Restart=on-failure
RestartSec=5
StandardOutput=append:/var/log/hysteria/hysteria.log
StandardError=append:/var/log/hysteria/hysteria.log

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable hysteria-server
systemctl start hysteria-server

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
      \"protocol\": \"hysteria2\",
      \"password\": \"$HYSTERIA_PASSWORD\",
      \"obfsPassword\": \"$OBFS_PASSWORD\",
      \"masqueradeUrl\": \"https://www.gosuslugi.ru\",
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
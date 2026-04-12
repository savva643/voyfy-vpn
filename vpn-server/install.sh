#!/bin/bash

# VoyFy VPN Server Auto-Installer
# XRay VLESS + XTLS-Reality

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PAIRING_CODE="${1:-}"
API_ENDPOINT="${API_ENDPOINT:-}"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  VoyFy VPN Server Installer${NC}"
echo -e "${BLUE}  XRay VLESS + XTLS-Reality${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}❌ Этот скрипт должен быть запущен от root${NC}"
   exit 1
fi

# Check pairing code
if [[ -z "$PAIRING_CODE" ]]; then
    echo -e "${RED}❌ Не указан код привязки${NC}"
    echo ""
    echo -e "${YELLOW}📋 Использование:${NC}"
    echo "  curl -fsSL https://your-domain.com/vpn-server/install.sh | sudo bash -s -- \"VOYFY-XXXXXX\""
    echo ""
    echo -e "${YELLOW}💡 Получите код в админ-панели:${NC}"
    echo "  https://your-domain.com/admin"
    exit 1
fi

# Interactive input for API endpoint if not provided via env
if [[ -z "$API_ENDPOINT" ]]; then
    echo -e "${YELLOW}📝 Введите API endpoint (например: https://api.voyfy.com):${NC}"
    read -r API_ENDPOINT
fi

if [[ -z "$API_ENDPOINT" ]]; then
    echo -e "${RED}❌ Не указан API endpoint${NC}"
    exit 1
fi

# Verify pairing code and get server details
echo -e "${YELLOW}🔐 Проверка кода привязки...${NC}"
VERIFY_RESPONSE=$(curl -s -X POST "$API_ENDPOINT/api/servers/verify-code" \
    -H "Content-Type: application/json" \
    -d "{\"code\": \"$PAIRING_CODE\"}" 2>/dev/null)

if ! echo "$VERIFY_RESPONSE" | jq -e '.success' >/dev/null 2>&1; then
    echo -e "${RED}❌ Неверный или истекший код привязки${NC}"
    echo "   $(echo "$VERIFY_RESPONSE" | jq -r '.message // "Unknown error"' 2>/dev/null)"
    exit 1
fi

SERVER_NAME=$(echo "$VERIFY_RESPONSE" | jq -r '.serverName')
SERVER_COUNTRY=$(echo "$VERIFY_RESPONSE" | jq -r '.country')
SERVER_PREMIUM=$(echo "$VERIFY_RESPONSE" | jq -r '.premium')

echo -e "${GREEN}✅ Код верифицирован${NC}"
echo -e "${YELLOW}📋 Конфигурация:${NC}"
echo "  Code: $PAIRING_CODE"
echo "  API: $API_ENDPOINT"
echo "  Server: $SERVER_NAME ($SERVER_COUNTRY)"
echo "  Type: $([[ "$SERVER_PREMIUM" == "true" ]] && echo "Premium" || echo "Free")"
echo ""

# Установка зависимостей
echo -e "${YELLOW}📦 Установка зависимостей...${NC}"
apt-get update -qq
apt-get install -y -qq curl wget jq uuid-runtime qrencode ufw

# Фаервол
echo -e "${YELLOW}🔓 Настройка фаервола...${NC}"
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp
ufw allow 443/tcp
ufw --force enable

# Установка XRay
echo -e "${YELLOW}🔧 Установка XRay...${NC}"
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install

# Генерация ключей
echo -e "${YELLOW}🔐 Генерация Reality ключей...${NC}"
KEYS=$(/usr/local/bin/xray x25519)
PRIVATE_KEY=$(echo "$KEYS" | grep "Private key:" | awk '{print $3}')
PUBLIC_KEY=$(echo "$KEYS" | grep "Public key:" | awk '{print $3}')
SHORT_ID=$(openssl rand -hex 4)
SERVER_IP=$(curl -s ifconfig.me)

# Конфигурация XRay
echo -e "${YELLOW}⚙️  Создание конфигурации...${NC}"
mkdir -p /usr/local/etc/xray /var/log/xray

cat > /usr/local/etc/xray/config.json <<EOF
{
  "log": {
    "loglevel": "warning",
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log"
  },
  "inbounds": [
    {
      "port": 443,
      "protocol": "vless",
      "settings": {
        "clients": [],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "dest": "www.google.com:443",
          "xver": 0,
          "serverNames": ["www.google.com", "www.youtube.com"],
          "privateKey": "$PRIVATE_KEY",
          "shortIds": ["", "$SHORT_ID"]
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
  ]
}
EOF

# Системный сервис XRay
cat > /etc/systemd/system/xray.service <<EOF
[Unit]
Description=XRay Service
After=network.target nss-lookup.target

[Service]
User=root
NoNewPrivileges=true
ExecStart=/usr/local/bin/xray run -config /usr/local/etc/xray/config.json
Restart=on-failure
RestartPreventExitStatus=23
LimitNPROC=10000
LimitNOFILE=1000000

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable xray
systemctl start xray

# Сохранение конфигурации
mkdir -p /opt/voyfy
cat > /opt/voyfy/config.json <<EOF
{
  "server": {
    "ip": "$SERVER_IP",
    "port": 443,
    "protocol": "vless"
  },
  "reality": {
    "privateKey": "$PRIVATE_KEY",
    "publicKey": "$PUBLIC_KEY",
    "shortId": "$SHORT_ID"
  },
  "api": {
    "endpoint": "$API_ENDPOINT"
  }
}
EOF

# Регистрация в API с кодом привязки
echo -e "${YELLOW}🌐 Регистрация сервера в API...${NC}"
RESPONSE=$(curl -s -X POST "$API_ENDPOINT/api/servers/register" \
    -H "Content-Type: application/json" \
    -d "{
        \"pairingCode\": \"$PAIRING_CODE\",
        \"host\": \"$SERVER_IP\",
        \"port\": 443,
        \"publicKey\": \"$PUBLIC_KEY\",
        \"serverNames\": [\"www.google.com\", \"www.youtube.com\"],
        \"shortId\": \"$SHORT_ID\"
    }" 2>/dev/null)

if echo "$RESPONSE" | jq -e '.success' >/dev/null 2>&1; then
    SERVER_ID=$(echo "$RESPONSE" | jq -r '.serverId')
    API_KEY=$(echo "$RESPONSE" | jq -r '.apiKey')
    echo -e "${GREEN}✅ Сервер зарегистрирован: $SERVER_ID${NC}"
    
    # Обновляем конфиг с serverId и apiKey
    cat > /opt/voyfy/config.json <<EOF
{
  "serverId": "$SERVER_ID",
  "apiKey": "$API_KEY",
  "server": {
    "ip": "$SERVER_IP",
    "port": 443,
    "protocol": "vless"
  },
  "reality": {
    "privateKey": "$PRIVATE_KEY",
    "publicKey": "$PUBLIC_KEY",
    "shortId": "$SHORT_ID"
  },
  "api": {
    "endpoint": "$API_ENDPOINT"
  }
}
EOF
    
    # Установка heartbeat
    cp "$(dirname "$0")/heartbeat.sh" /opt/voyfy/heartbeat.sh
    chmod +x /opt/voyfy/heartbeat.sh
    
    # Systemd сервис для heartbeat
    cat > /etc/systemd/system/voyfy-heartbeat.service <<EOF
[Unit]
Description=VoyFy Heartbeat
After=network.target xray.service

[Service]
Type=simple
ExecStart=/opt/voyfy/heartbeat.sh
Restart=always
RestartSec=10
User=root

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable voyfy-heartbeat
    systemctl start voyfy-heartbeat
    
else
    echo -e "${RED}❌ Ошибка активации:${NC}"
    echo "$RESPONSE" | jq -r '.message // "Unknown error"' 2>/dev/null || echo "$RESPONSE"
    exit 1
fi

# Вывод информации
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  ✅ VPN Сервер готов!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${BLUE}📊 Информация:${NC}"
echo "  IP: $SERVER_IP"
echo "  Port: 443"
echo "  Public Key: $PUBLIC_KEY"
echo ""
echo -e "${YELLOW}📝 Управление:${NC}"
echo "  systemctl status xray        - статус VPN"
echo "  systemctl status voyfy-heartbeat - статус мониторинга"
echo "  cat /var/log/xray/error.log  - логи"
echo ""
echo -e "${GREEN}🚀 Сервер добавлен в пул и доступен пользователям!${NC}"

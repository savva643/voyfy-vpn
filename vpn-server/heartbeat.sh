#!/bin/bash

# VoyFy VPN Server Heartbeat
# Отправляет статус сервера в API

API_ENDPOINT="${API_ENDPOINT:-$(cat /opt/voyfy/config.json 2>/dev/null | jq -r '.api.endpoint // empty')}"
API_KEY="${API_KEY:-$(cat /opt/voyfy/config.json 2>/dev/null | jq -r '.apiKey // empty')}"
SERVER_ID="${SERVER_ID:-$(cat /opt/voyfy/config.json 2>/dev/null | jq -r '.serverId // empty')}"

if [[ -z "$API_ENDPOINT" || -z "$API_KEY" || -z "$SERVER_ID" ]]; then
    echo "❌ Не настроены API параметры"
    exit 1
fi

# Получаем статистику
get_stats() {
    # Количество соединений
    local connections=0
    if [[ -f /var/log/xray/access.log ]]; then
        local five_min_ago=$(date -d '5 minutes ago' '+%Y/%m/%d %H:%M:%S' 2>/dev/null || echo "")
        if [[ -n "$five_min_ago" ]]; then
            connections=$(grep -c "$five_min_ago" /var/log/xray/access.log 2>/dev/null || echo 0)
        fi
    fi
    
    # CPU и RAM
    local cpu=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1 || echo 0)
    local ram=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100}' || echo 0)
    local load=$(echo "($cpu + $ram) / 2" | bc 2>/dev/null || echo 0)
    
    echo "${load%.*} $connections"
}

# Отправка heartbeat
send_heartbeat() {
    local stats=$(get_stats)
    local load=$(echo "$stats" | awk '{print $1}')
    local users=$(echo "$stats" | awk '{print $2}')
    
    curl -s -X POST "$API_ENDPOINT/api/servers/$SERVER_ID/heartbeat" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $API_KEY" \
        -d "{\"loadPercent\": $load, \"currentUsers\": $users}" \
        > /dev/null 2>&1
}

# Основной цикл
while true; do
    send_heartbeat
    sleep 60
done

#!/bin/bash

# VoyFy VPN Server Heartbeat
# Отправляет статус сервера в API

CONFIG_FILE="/opt/voyfy/config.json"

# Читаем конфиг
if [[ -f "$CONFIG_FILE" ]]; then
    API_ENDPOINT="${API_ENDPOINT:-$(cat $CONFIG_FILE | jq -r '.api.endpoint // .apiEndpoint // empty')}"
    API_KEY="${API_KEY:-$(cat $CONFIG_FILE | jq -r '.apiKey // empty')}"
    SERVER_ID="${SERVER_ID:-$(cat $CONFIG_FILE | jq -r '.serverId // empty')}"
fi

if [[ -z "$API_ENDPOINT" || -z "$API_KEY" || -z "$SERVER_ID" ]]; then
    echo "❌ Не настроены API параметры"
    echo "API_ENDPOINT: ${API_ENDPOINT:-не задан}"
    echo "API_KEY: ${API_KEY:-не задан}"
    echo "SERVER_ID: ${SERVER_ID:-не задан}"
    exit 1
fi

# Получаем пинг до API
get_ping() {
    local ping_ms=0
    # Пытаемся получить пинг через ping команду
    local api_host=$(echo "$API_ENDPOINT" | sed 's|https://||' | sed 's|http://||' | cut -d'/' -f1)
    if command -v ping &> /dev/null; then
        ping_ms=$(ping -c 1 -W 2 "$api_host" 2>/dev/null | grep 'time=' | sed 's/.*time=\([0-9.]*\).*/\1/' | cut -d'.' -f1)
    fi
    # Если ping не сработал, используем curl timing
    if [[ -z "$ping_ms" ]] || [[ "$ping_ms" == "0" ]]; then
        ping_ms=$(curl -s -o /dev/null -w "%{time_total}" "$API_ENDPOINT/health" 2>/dev/null | awk '{print int($1*1000)}')
    fi
    echo "${ping_ms:-0}"
}

# Получаем статистику
get_stats() {
    # Количество активных соединений Xray
    local connections=0
    if command -v ss &> /dev/null; then
        connections=$(ss -tuln | grep -c ":443" 2>/dev/null || echo 0)
    elif command -v netstat &> /dev/null; then
        connections=$(netstat -tuln 2>/dev/null | grep -c ":443" || echo 0)
    fi
    
    # CPU load (1-min average)
    local cpu_load=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//' 2>/dev/null || echo 0)
    
    # RAM usage percentage
    local ram_percent=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100}' 2>/dev/null || echo 0)
    
    # Общая нагрузка (0-100%)
    local load=$((ram_percent))
    if [[ $(echo "$cpu_load > 1" | bc 2>/dev/null || echo 0) -eq 1 ]]; then
        load=$((load + 10))
    fi
    
    # Ограничиваем 100%
    if [[ $load -gt 100 ]]; then
        load=100
    fi
    
    echo "$load $connections"
}

# Отправка heartbeat
send_heartbeat() {
    local stats=$(get_stats)
    local load=$(echo "$stats" | awk '{print $1}')
    local users=$(echo "$stats" | awk '{print $2}')
    local ping=$(get_ping)
    
    # Отправляем heartbeat
    local response=$(curl -s -X POST "$API_ENDPOINT/api/servers/$SERVER_ID/heartbeat" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $API_KEY" \
        -d "{\"loadPercent\": $load, \"currentUsers\": $users, \"ping\": $ping}" \
        2>/dev/null)
    
    # Логируем для отладки
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Load: ${load}%, Users: ${users}, Ping: ${ping}ms"
}

# Первый запуск сразу
send_heartbeat

# Основной цикл
while true; do
    sleep 30
    send_heartbeat
done

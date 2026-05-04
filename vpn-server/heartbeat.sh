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

# Получаем реальную статистику из Xray API
get_xray_stats() {
    local xray_users=0
    local xray_up=0
    local xray_down=0
    
    # Получаем статистику из Xray API (localhost:10085)
    if command -v curl &> /dev/null; then
        local stats=$(curl -s "http://localhost:10085/stats/query" 2>/dev/null || echo "")
        if [[ -n "$stats" ]]; then
            xray_users=$(echo "$stats" | grep -o '"email"[^}]*' | sort -u | wc -l)
            xray_up=$(echo "$stats" | grep -o '"uplink":[0-9]*' | grep -o '[0-9]*' | awk '{s+=$1} END {print s}')
            xray_down=$(echo "$stats" | grep -o '"downlink":[0-9]*' | grep -o '[0-9]*' | awk '{s+=$1} END {print s}')
        fi
    fi
    # Fallback: считаем уникальные IP вместо всех соединений
    if [[ "$xray_users" -eq 0 ]]; then
        if command -v ss &> /dev/null; then
            xray_users=$(ss -tn state established 2>/dev/null | grep ":8444" | awk '{print $5}' | cut -d: -f1 | sort -u | wc -l)
        elif command -v netstat &> /dev/null; then
            xray_users=$(netstat -tn 2>/dev/null | grep ESTABLISHED | grep ":8444" | awk '{print $5}' | cut -d: -f1 | sort -u | wc -l)
        fi
    fi
    echo "$xray_users $xray_up $xray_down"
}

# Получаем статистику системы
get_stats() {
    # Получаем реальную статистику Xray
    local xray_stats=$(get_xray_stats)
    local connections=$(echo "$xray_stats" | awk '{print $1}')
    local traffic_up=$(echo "$xray_stats" | awk '{print $2}')
    local traffic_down=$(echo "$xray_stats" | awk '{print $3}')
    
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
    
    echo "$load $connections $traffic_up $traffic_down"
}

# Синхронизация клиентов с backend
sync_clients() {
    # Получаем список клиентов от API
    local response=$(curl -s -X GET "$API_ENDPOINT/api/servers/$SERVER_ID/clients" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $API_KEY" \
        2>/dev/null)
    
    # Проверяем успешность запроса
    if ! echo "$response" | jq -e '.success' >/dev/null 2>&1; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Failed to fetch clients from API"
        return 1
    fi
    
    # Извлекаем клиентов
    local clients=$(echo "$response" | jq -r '.clients // []')
    local client_count=$(echo "$clients" | jq 'length')
    
    if [ "$client_count" -eq 0 ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] No active clients to sync"
        return 0
    fi
    
    # Читаем текущий конфиг
    local config_file="/usr/local/etc/xray/config.json"
    if [ ! -f "$config_file" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Xray config not found!"
        return 1
    fi
    
    # Сохраняем бэкап
    cp "$config_file" "$config_file.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Создаем новый конфиг с обновленным clients массивом
    local current_config=$(cat "$config_file")
    local new_config=$(echo "$current_config" | jq --argjson new_clients "$clients" '.inbounds[0].settings.clients = $new_clients')
    
    if [ -n "$new_config" ]; then
        echo "$new_config" > "$config_file"
        
        # Перезапускаем Xray только если конфиг изменился
        systemctl reload xray 2>/dev/null || systemctl restart xray
        
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Synced $client_count clients, Xray reloaded"
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Failed to update config"
        return 1
    fi
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
sync_clients  # Sync clients on startup
send_heartbeat

# Основной цикл
SYNC_COUNTER=0
while true; do
    sleep 30
    send_heartbeat
    
    # Синхронизируем клиентов каждые 5 минут (10 циклов по 30 сек)
    SYNC_COUNTER=$((SYNC_COUNTER + 1))
    if [ $SYNC_COUNTER -ge 10 ]; then
        sync_clients
        SYNC_COUNTER=0
    fi
done

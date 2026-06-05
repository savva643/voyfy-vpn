#!/bin/bash
 
CONFIG_FILE="/opt/voyfy-vpn/vpn-server/config.json"
 
if [[ -f "$CONFIG_FILE" ]]; then
    API_ENDPOINT="${API_ENDPOINT:-$(cat $CONFIG_FILE | jq -r '.api.endpoint // empty')}"
    API_KEY="${API_KEY:-$(cat $CONFIG_FILE | jq -r '.apiKey // empty')}"
    SERVER_ID="${SERVER_ID:-$(cat $CONFIG_FILE | jq -r '.serverId // empty')}"
fi
 
if [[ -z "$API_ENDPOINT" || -z "$API_KEY" || -z "$SERVER_ID" ]]; then
    echo "❌ Не настроены API параметры"
    exit 1
fi
 
get_ping() {
    local time_sec=$(curl -s -o /dev/null -w "%{time_total}" "$API_ENDPOINT/api/health" 2>/dev/null)
    local ping_ms=$(echo "$time_sec * 1000 / 1" | bc 2>/dev/null || echo "0")
    echo "${ping_ms:-0}"
}
 
get_stats() {
    local load=0
    if [[ -f /proc/loadavg ]]; then
        local cpus=$(nproc 2>/dev/null || echo 1)
        local load1=$(cat /proc/loadavg | awk '{print $1}')
        load=$(echo "scale=0; $load1 * 100 / $cpus" | bc 2>/dev/null || echo "0")
    fi
    
    local users=0
    if command -v ss &> /dev/null; then
        users=$(ss -tn 2>/dev/null | grep ":8444" | grep ESTAB | wc -l)
    fi
    
    echo "$load $users"
}
 
sync_clients() {
    local response=$(curl -s "$API_ENDPOINT/api/servers/$SERVER_ID/clients" \
        -H "Authorization: Bearer $API_KEY" \
        --max-time 10 2>/dev/null)
    
    if ! echo "$response" | grep -q '"success":true'; then
        echo "[$(date '+%H:%M:%S')] Failed to fetch clients"
        return 1
    fi
    
    local clients=$(echo "$response" | jq -r '.clients // []' 2>/dev/null)
    local count=$(echo "$clients" | jq 'length' 2>/dev/null || echo 0)
    
    if [[ "$count" -eq 0 ]]; then
        echo "[$(date '+%H:%M:%S')] No clients to sync"
        return 0
    fi
    
    local config_file="/usr/local/etc/xray/config.json"
    if [[ ! -f "$config_file" ]]; then
        echo "[$(date '+%H:%M:%S')] Xray config not found"
        return 1
    fi
    
    local new_config=$(cat "$config_file" | jq --argjson new_clients "$clients" '.inbounds[0].settings.clients = $new_clients' 2>/dev/null)
    
    if [[ -n "$new_config" ]]; then
        echo "$new_config" > "$config_file"
        systemctl reload xray 2>/dev/null || systemctl restart xray
        echo "[$(date '+%H:%M:%S')] Synced $count clients, Xray reloaded"
    else
        echo "[$(date '+%H:%M:%S')] Failed to update config"
        return 1
    fi
}
 
send_heartbeat() {
    local stats=$(get_stats)
    local load=$(echo "$stats" | awk '{print $1}')
    local users=$(echo "$stats" | awk '{print $2}')
    local ping=$(get_ping)
    
    curl -s -X POST "$API_ENDPOINT/api/servers/$SERVER_ID/heartbeat" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $API_KEY" \
        -d "{\"loadPercent\": $load, \"currentUsers\": $users, \"ping\": $ping}" \
        --max-time 10 2>/dev/null
    
    echo "[$(date '+%H:%M:%S')] Load: ${load}%, Users: ${users}, Ping: ${ping}ms"
}
 
sync_clients
send_heartbeat
 
SYNC_COUNTER=0
 
while true; do
    sleep 30
    send_heartbeat
    
    SYNC_COUNTER=$((SYNC_COUNTER + 1))
    if [[ $SYNC_COUNTER -ge 10 ]]; then
        sync_clients
        SYNC_COUNTER=0
    fi
done
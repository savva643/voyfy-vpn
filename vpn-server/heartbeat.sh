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
    # Measure latency to API endpoint (skip if API is on same VPS)
    local time_sec=$(curl -s -o /dev/null -w "%{time_total}" --max-time 5 "$API_ENDPOINT/api/health" 2>/dev/null)
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
        # Count unique client IPs connected to Hysteria2 QUIC port
        # Parse peer address from any column position (robust across distros)
        users=$(ss -un "sport = :8444" 2>/dev/null \
            | awk 'NR>1' \
            | grep -oP '[\d]+\.[\d]+\.[\d]+\.[\d]+(?=:)' \
            | sort -u \
            | wc -l)
    fi
    
    echo "$load $users"
}
 
sync_clients() {
    local response=$(curl -s -w "\n%{http_code}" "$API_ENDPOINT/api/servers/$SERVER_ID/clients" \
        -H "Authorization: Bearer $API_KEY" \
        --max-time 10 2>/dev/null)
    
    local http_code=$(echo "$response" | tail -1)
    local body=$(echo "$response" | sed '$d')
    
    if [[ "$http_code" != "200" ]]; then
        echo "[$(date '+%H:%M:%S')] Failed to fetch clients (HTTP $http_code)"
        return 1
    fi
    
    if ! echo "$body" | grep -q '"success":true'; then
        echo "[$(date '+%H:%M:%S')] Failed to fetch clients: $(echo "$body" | jq -r '.message // "unknown error"' 2>/dev/null)"
        return 1
    fi
    
    local count=$(echo "$body" | jq -r '.clientCount // 0' 2>/dev/null || echo 0)
    
    # Check that Hysteria2 service is running
    if ! systemctl is-active --quiet hysteria-server; then
        echo "[$(date '+%H:%M:%S')] Hysteria2 server not running, restarting..."
        systemctl restart hysteria-server 2>/dev/null || true
        return 1
    fi
    
    echo "[$(date '+%H:%M:%S')] Sync OK - ${count} clients, Hysteria2 running"
}
 
send_heartbeat() {
    local stats=$(get_stats)
    local load=$(echo "$stats" | awk '{print $1}')
    local users=$(echo "$stats" | awk '{print $2}')
    local ping=$(get_ping)
    
    local response=$(curl -s -w "\n%{http_code}" -X POST "$API_ENDPOINT/api/servers/$SERVER_ID/heartbeat" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $API_KEY" \
        -d "{\"loadPercent\": $load, \"currentUsers\": $users, \"ping\": $ping}" \
        --max-time 10 2>/dev/null)
    
    local http_code=$(echo "$response" | tail -1)
    local body=$(echo "$response" | sed '$d')
    
    if [[ "$http_code" == "200" ]]; then
        echo "[$(date '+%H:%M:%S')] Heartbeat OK - Load: ${load}%, Users: ${users}, Ping: ${ping}ms"
    else
        echo "[$(date '+%H:%M:%S')] Heartbeat FAILED (HTTP $http_code) - Load: ${load}%, Users: ${users}"
    fi
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
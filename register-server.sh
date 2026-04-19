#!/bin/bash

# Server Registration Script
# Run this on the same VPS after generating a pairing code in admin panel

API_URL="https://vip.necsoura.ru"
PAIRING_CODE=""
HOST="185.164.163.166"
PORT="8443"
PROVIDER="xray"

echo "======================================"
echo "Voyfy VPN Server Registration"
echo "======================================"
echo "API URL: $API_URL"
echo "Host: $HOST:$PORT"
echo "Provider: $PROVIDER"
echo "======================================"

# Check if pairing code is provided
if [ -z "$PAIRING_CODE" ]; then
    echo "Usage: ./register-server.sh <pairing_code>"
    echo "Example: ./register-server.sh ABC123XYZ"
    exit 1
fi

# Register server
echo "Registering server with pairing code: $PAIRING_CODE"
RESPONSE=$(curl -s -X POST "$API_URL/api/servers/register" \
  -H "Content-Type: application/json" \
  -d "{
    \"pairingCode\": \"$PAIRING_CODE\",
    \"host\": \"$HOST\",
    \"port\": $PORT,
    \"provider\": \"$PROVIDER\"
  }")

echo "Response: $RESPONSE"

# Check if registration was successful
if echo "$RESPONSE" | grep -q "success.*true"; then
    echo "======================================"
    echo "Server registered successfully!"
    echo "======================================"
    echo "You can now see the server in:"
    echo "- Admin Panel: $API_URL/admin"
    echo "- Flutter App (after API URL update)"
    echo "======================================"
else
    echo "======================================"
    echo "Registration failed!"
    echo "======================================"
    echo "Please check:"
    echo "1. Pairing code is valid"
    echo "2. Backend API is running"
    echo "3. Network connectivity"
    echo "======================================"
    exit 1
fi

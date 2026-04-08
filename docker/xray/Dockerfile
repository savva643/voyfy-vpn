FROM teddysun/xray:latest

# Remove default config directory if exists
RUN rm -rf /tmp/xray-config.json 2>/dev/null || true

# Copy template
COPY config.json.template /tmp/xray-config.json.template
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]

#!/bin/bash
# Trinity VPS Deployment Script
# Run on VPS after SCP transfer

set -e

DEPLOY_DIR="/opt/trinity"

echo "=== Trinity VPS Deployment ==="

# Create directory
mkdir -p $DEPLOY_DIR/bin

# Move binary
mv /root/vibee $DEPLOY_DIR/bin/
chmod +x $DEPLOY_DIR/bin/vibee

# Create systemd service if not exists
if [ ! -f /etc/systemd/system/trinity-api.service ]; then
cat > /etc/systemd/system/trinity-api.service << 'SVCEOF'
[Unit]
Description=Trinity GGUF Inference API
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/trinity
ExecStart=/opt/trinity/bin/vibee serve --model /opt/trinity/models/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf --port 8080
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SVCEOF
fi

# Reload and restart
systemctl daemon-reload
systemctl restart trinity-api
systemctl status trinity-api

echo "=== Deployment Complete ==="

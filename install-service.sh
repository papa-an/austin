#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_FILE="$SCRIPT_DIR/austin-ui.service"

if [ ! -f "$SERVICE_FILE" ]; then
  echo "Error: austin-ui.service not found in $SCRIPT_DIR"
  exit 1
fi

echo "Installing Austin UI service..."
echo "Make sure you've edited austin-ui.service with your username and paths first!"
echo ""

sudo cp "$SERVICE_FILE" /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable austin-ui
sudo systemctl start austin-ui
sudo systemctl status austin-ui

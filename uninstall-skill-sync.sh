#!/bin/bash

if [ "$EUID" -ne 0 ]; then
  echo "Vui long chay script bang quyen sudo: sudo ./uninstall-skill-sync.sh"
  exit 1
fi

if [ -z "$1" ]; then
  echo "Usage: sudo ./uninstall-skill-sync.sh <service-name>"
  echo "Vi du: sudo ./uninstall-skill-sync.sh opencode-skill-sync"
  exit 1
fi

SERVICE_NAME="$1"
SERVICE_FILE="${SERVICE_NAME}.service"
PATH_FILE="${SERVICE_NAME}.path"
CONFIG_FILE="/etc/${SERVICE_NAME}.conf"

echo "=== Go cai dat Skill Sync Service ==="
echo "Service: $SERVICE_FILE"
echo "Path: $PATH_FILE"
echo "Config: $CONFIG_FILE"

read -p "Ban co chan chan muon go cai dat? [y/N]: " CONFIRM
if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
    echo "Huy bo."
    exit 0
fi

echo "-> Stop va disable services..."
systemctl stop "$SERVICE_FILE" 2>/dev/null
systemctl disable "$SERVICE_FILE" 2>/dev/null
systemctl stop "$PATH_FILE" 2>/dev/null
systemctl disable "$PATH_FILE" 2>/dev/null

echo "-> Xoa systemd unit files..."
rm -f /etc/systemd/system/"$SERVICE_FILE"
rm -f /etc/systemd/system/"$PATH_FILE"
rm -f /etc/systemd/system/multi-user.target.wants/"$SERVICE_FILE"
rm -f /etc/systemd/system/multi-user.target.wants/"$PATH_FILE"

echo "-> Xoa config file..."
rm -f "$CONFIG_FILE"

echo "-> Reloading systemd..."
systemctl daemon-reload
systemctl reset-failed

echo "-> Xoa cron entry..."
CRON_LINE="/usr/local/bin/skill-sync.sh.*--config $CONFIG_FILE"
(crontab -l 2>/dev/null | grep -v "$CONFIG_FILE") | crontab -

echo "=== Hoan tat! ==="
echo "Da go cac thanh phan cua $SERVICE_NAME"
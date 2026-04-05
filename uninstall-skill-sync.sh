#!/bin/bash

if [ "$EUID" -ne 0 ]; then
  echo "Vui long chay script bang quyen sudo: sudo ./uninstall-skill-sync.sh"
  exit 1
fi

echo "=== Go cai dat Skill Sync Service ==="

configs=$(ls /etc/*skill-sync*.conf 2>/dev/null)

if [ -z "$configs" ]; then
    echo "Khong tim thay service nao duoc cai dat boi script nay."
    exit 0
fi

declare -a SERVICES
index=1

echo ""
echo "=== Cac service da cai dat ==="
while IFS= read -r config; do
    service_name=$(basename "$config" .conf)
    SERVICES[$index]=$service_name
    echo "  $index) $service_name"
    index=$((index + 1))
done <<< "$configs"

echo ""
read -p "Chon service muon go cai (1-$((index - 1))) hoac 'q' de thoat: " choice

if [ "$choice" = "q" ] || [ "$choice" = "Q" ]; then
    echo "Huy bo."
    exit 0
fi

if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -ge "$index" ]; then
    echo "Lua chon khong hop le."
    exit 1
fi

SERVICE_NAME="${SERVICES[$choice]}"
SERVICE_FILE="${SERVICE_NAME}.service"
PATH_FILE="${SERVICE_NAME}.path"
CONFIG_FILE="/etc/${SERVICE_NAME}.conf"

echo ""
echo "Service: $SERVICE_NAME"
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
(crontab -l 2>/dev/null | grep -v "$CONFIG_FILE") | crontab -

echo ""
echo "=== Hoan tat! ==="
echo "Da go cac thanh phan cua $SERVICE_NAME"
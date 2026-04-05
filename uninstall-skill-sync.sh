#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLED_FILE="$SCRIPT_DIR/installed-services.txt"

if [ "$EUID" -ne 0 ]; then
  echo "Vui long chay script bang quyen sudo: sudo ./uninstall-skill-sync.sh"
  exit 1
fi

echo "=== Go cai dat Skill Sync Service ==="

if [ ! -f "$INSTALLED_FILE" ]; then
    echo "Khong tim thay file danh sach dich vu ($INSTALLED_FILE)."
    echo "Vui long kiem tra lai duong dan script."
    exit 0
fi

if [ ! -s "$INSTALLED_FILE" ]; then
    echo "Khong co service nao duoc ghi nhan."
    rm -f "$INSTALLED_FILE"
    exit 0
fi

declare -a SERVICES
index=1

echo ""
echo "=== Cac service da cai dat ==="
while IFS= read -r line; do
    [ -z "$line" ] && continue
    service_name=$(echo "$line" | cut -d'|' -f1)
    SERVICES[$index]="$line"
    echo "  $index) $service_name"
    index=$((index + 1))
done < "$INSTALLED_FILE"

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

selected="${SERVICES[$choice]}"
SERVICE_NAME=$(echo "$selected" | cut -d'|' -f1)
CONFIG_FILE=$(echo "$selected" | cut -d'|' -f2)
SERVICE_FILE="${SERVICE_NAME}.service"
PATH_FILE="${SERVICE_NAME}.path"

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

echo "-> Xoa khoi installed-services.txt..."
grep -v "^${SERVICE_NAME}|" "$INSTALLED_FILE" > /tmp/installed-services.tmp
mv /tmp/installed-services.tmp "$INSTALLED_FILE"

if [ ! -s "$INSTALLED_FILE" ]; then
    rm -f "$INSTALLED_FILE"
fi

echo ""
echo "=== Hoan tat! ==="
echo "Da go cac thanh phan cua $SERVICE_NAME"
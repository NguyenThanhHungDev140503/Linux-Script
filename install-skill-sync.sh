#!/bin/bash

if [ "$EUID" -ne 0 ]; then
  echo "Vui long chay script bang quyen sudo: sudo ./install-skill-sync.sh"
  exit 1
fi

echo "=== Cai dat Skill Auto Sync Service ==="

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLED_FILE="$SCRIPT_DIR/installed-services.txt"
SCRIPT_NAME="skill-sync.sh"

SUDO_USER="${SUDO_USER:-$(whoami)}"
SUDO_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)

read -p "Nhap ten service (vi du: skill-sync-doc): " SERVICE_NAME

if [ -f "$INSTALLED_FILE" ] && grep -q "^${SERVICE_NAME}|" "$INSTALLED_FILE" 2>/dev/null; then
    echo "[WARN] Service '$SERVICE_NAME' da ton tai trong he thong."
    read -p "Ban co muon ghi de? [y/N]: " OVERWRITE
    if [ "$OVERWRITE" != "y" ] && [ "$OVERWRITE" != "Y" ]; then
        echo "Huy bo cai dat."
        exit 0
    fi
fi

SERVICE_FILE="${SERVICE_NAME}.service"
PATH_FILE="${SERVICE_NAME}.path"
CONFIG_FILE="/etc/${SERVICE_NAME}.conf"

read -p "Nhap duong dan nguon (SRC): " SRC
read -p "Nhap duong dan dich (DEST): " DEST

if [ -z "$SRC" ] || [ -z "$DEST" ]; then
    echo "[ERROR] SRC va DEST khong duoc de trong"
    exit 1
fi

read -p "Ban co muon xoa cac file thua trong DEST (khong co trong SRC)? [y/N]: " DELETE_CONFIRM
if [ "$DELETE_CONFIRM" = "y" ] || [ "$DELETE_CONFIRM" = "Y" ]; then
    DELETE_ON_SYNC=true
else
    DELETE_ON_SYNC=false
fi

echo "-> Tao config file..."
echo "SRC=\"$SRC\"" > "$CONFIG_FILE"
echo "DEST=\"$DEST\"" >> "$CONFIG_FILE"
echo "DELETE_ON_SYNC=$DELETE_ON_SYNC" >> "$CONFIG_FILE"
chmod 644 "$CONFIG_FILE"

echo "-> Copy script vao he thong..."
chmod +x "$SCRIPT_NAME"
cp "$SCRIPT_NAME" /usr/local/bin/

echo "-> Tao service file (Type=oneshot)..."
sed "s|/usr/local/bin/skill-sync.sh|/usr/local/bin/skill-sync.sh --config $CONFIG_FILE|g" skill-sync.service > /tmp/"$SERVICE_FILE"
cp /tmp/"$SERVICE_FILE" /etc/systemd/system/

echo "-> Tao path unit file..."
sed "s|__SRC_PATH__|$SRC|g" skill-sync.path > /tmp/"$PATH_FILE"
cp /tmp/"$PATH_FILE" /etc/systemd/system/

echo "-> Reloading systemd..."
systemctl daemon-reload

echo "-> Enable services..."
systemctl enable "$PATH_FILE"
systemctl enable "$SERVICE_FILE"

echo "-> Cai dat cron backup (5 phut)..."
CRON_JOB="*/5 * * * * /usr/local/bin/skill-sync.sh --once --config $CONFIG_FILE"
su - "$SUDO_USER" -c "crontab -l 2>/dev/null | grep -v '$CONFIG_FILE' ; echo '$CRON_JOB' | crontab -"

echo "-> Luu vao installed-services.txt..."
echo "${SERVICE_NAME}|${CONFIG_FILE}" >> "$INSTALLED_FILE"

echo "-> Kiem tra sync lan dau..."
if ! /usr/local/bin/skill-sync.sh --once --config "$CONFIG_FILE"; then
    echo ""
    echo "[ERROR] Sync lan dau that bai. Vui long kiem tra:"
    echo "  - DEST co ton tai khong: $DEST"
    echo "  - Google Drive da duoc mount chua?"
    echo ""
    read -p "Ban co van muon tiep tuc cau hinh service? [y/N]: " CONTINUE
    if [ "$CONTINUE" != "y" ] && [ "$CONTINUE" != "Y" ]; then
        echo "-> Huy bo va don dep..."
        systemctl stop "$SERVICE_FILE" "$PATH_FILE" 2>/dev/null
        systemctl disable "$SERVICE_FILE" "$PATH_FILE" 2>/dev/null
        rm -f /etc/systemd/system/"$SERVICE_FILE"
        rm -f /etc/systemd/system/"$PATH_FILE"
        rm -f "$CONFIG_FILE"
        systemctl daemon-reload 2>/dev/null
        echo "[OK] Da huy bo hoan toan."
        exit 1
    fi
fi

echo ""
echo "=== Hoan tat! ==="
echo "Service: $SERVICE_FILE"
echo "Path unit: $PATH_FILE"
echo "Config: $CONFIG_FILE"
echo "SRC: $SRC"
echo "DEST: $DEST"
echo "DELETE_ON_SYNC: $DELETE_ON_SYNC"
echo "Cron user: $SUDO_USER"
echo ""
echo "Lenh kiem tra:"
echo "  systemctl status $PATH_FILE"
echo "  systemctl status $SERVICE_FILE"
echo "  sudo journalctl -u $SERVICE_FILE -f"
echo "  crontab -l | grep skill-sync"
#!/bin/bash

LOG_FILE="/home/nguyen-thanh-hung/.local/state/skill-sync.log"
CONFIG_FILE="/etc/skill-sync.conf"
ONCE_MODE=false

while [ $# -gt 0 ]; do
    case "$1" in
        --config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        --once)
            ONCE_MODE=true
            shift
            ;;
        *)
            shift
            ;;
    esac
done

if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    if [ -z "$SRC" ] || [ -z "$DEST" ]; then
        read -p "Nhap duong dan nguon (SRC): " SRC
        read -p "Nhap duong dan dich (DEST): " DEST
    fi

    if [ -z "$SRC" ] || [ -z "$DEST" ]; then
        echo "[ERROR] SRC va DEST khong duoc de trong" | tee -a "$LOG_FILE"
        exit 1
    fi
fi

if [ -z "$DELETE_ON_SYNC" ]; then
    DELETE_ON_SYNC=false
fi

if ! command -v inotifywait >/dev/null 2>&1; then
    echo "[ERROR] inotifywait (inotify-tools) chua duoc cai. Vui long cai: sudo apt install inotify-tools" \
        | tee -a "$LOG_FILE"
    exit 1
fi

echo "=== Skill Sync Service Started ===" | tee -a "$LOG_FILE"
echo "[INFO] SRC: $SRC" | tee -a "$LOG_FILE"
echo "[INFO] DEST: $DEST" | tee -a "$LOG_FILE"
echo "[INFO] DELETE_ON_SYNC: $DELETE_ON_SYNC" | tee -a "$LOG_FILE"

sync_once() {
    echo "[SYNC] $(date '+%Y-%m-%d %H:%M:%S') - Dang dong bo..." | tee -a "$LOG_FILE"

    if [ ! -d "$DEST" ] || [ ! -w "$DEST" ]; then
        echo "[WARN] DEST chua san sang (khong ton tai hoac khong ghi duoc): $DEST" | tee -a "$LOG_FILE"
        return 1
    fi

    if [ "$DELETE_ON_SYNC" = true ]; then
        RSYNC_CMD="rsync -av --delete"
    else
        RSYNC_CMD="rsync -av"
    fi

    $RSYNC_CMD "$SRC"/ "$DEST"/ >>"$LOG_FILE" 2>&1
    if [ $? -eq 0 ]; then
        echo "[OK] Sync hoan tat." | tee -a "$LOG_FILE"
        return 0
    else
        echo "[ERROR] Sync loi." | tee -a "$LOG_FILE"
        return 1
    fi
}

mkdir -p "$SRC"

if [ "$ONCE_MODE" = true ]; then
    sync_once
    exit $?
fi

sync_once

inotifywait -m -r \
    -e modify,create,delete,move \
    --format '%w%f %e' \
    "$SRC" | while read file event; do
        echo "[EVENT] $event on $file" | tee -a "$LOG_FILE"
        sync_once
    done
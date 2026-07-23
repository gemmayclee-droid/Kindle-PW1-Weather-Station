#!/bin/sh

BASE="/mnt/us/extensions/weatheriot"
LOG="$BASE/log.txt"
CRON_FILE="/tmp/weatheriot.cron"
JOB="/bin/sh $BASE/worker.sh >> $LOG 2>&1"

cd "$BASE" || exit 1

INTERVAL=$(grep "<interval>" config.xml | sed 's/.*<interval>\(.*\)<\/interval>.*/\1/' | tr -d '\r' | tr -d ' ')

case "$INTERVAL" in
    *[!0-9]*|"")
        INTERVAL=21600
        ;;
esac

HOURS=$((INTERVAL / 3600))

if [ "$HOURS" -lt 1 ]; then
    HOURS=6
fi

echo "=== 安裝省電定時更新: $(date) ===" >> "$LOG"
echo "更新間隔: $HOURS 小時" >> "$LOG"

if command -v crontab >/dev/null 2>&1; then
    crontab -l 2>/dev/null | grep -v "$BASE/worker.sh" > "$CRON_FILE"
    echo "0 */$HOURS * * * $JOB" >> "$CRON_FILE"
    crontab "$CRON_FILE" >> "$LOG" 2>&1
    rm -f "$CRON_FILE"
else
    echo "ERROR: 找不到 crontab，無法安裝定時更新" >> "$LOG"
    exit 1
fi

if command -v crond >/dev/null 2>&1; then
    if ! pidof crond >/dev/null 2>&1; then
        crond >> "$LOG" 2>&1
    fi
fi

/bin/sh "$BASE/worker.sh" >> "$LOG" 2>&1 &

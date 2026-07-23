#!/bin/sh

BASE="/mnt/us/extensions/weatheriot"
LOG="$BASE/log.txt"
CRON_FILE="/tmp/weatheriot.cron"

echo "=== 移除省電定時更新: $(date) ===" >> "$LOG"

if command -v crontab >/dev/null 2>&1; then
    crontab -l 2>/dev/null | grep -v "$BASE/worker.sh" > "$CRON_FILE"
    crontab "$CRON_FILE" >> "$LOG" 2>&1
    rm -f "$CRON_FILE"
fi

pkill -f "$BASE/worker.sh" >> "$LOG" 2>&1
lipc-set-prop com.lab126.cmd wirelessEnable 0 >> "$LOG" 2>&1
lipc-set-prop com.lab126.powerd preventScreenSaver 0 >> "$LOG" 2>&1


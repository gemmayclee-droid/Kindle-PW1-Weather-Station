#!/bin/sh

BASE="/mnt/us/extensions/weatheriot"
LOG="$BASE/log.txt"
PID_FILE="$BASE/schedule.pid"
CRON_FILE="/tmp/weatheriot.cron"

echo "=== 移除省電定時更新: $(date) ===" >> "$LOG"

if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE" 2>/dev/null)
    case "$OLD_PID" in
        *[!0-9]*|"") ;;
        *) kill "$OLD_PID" >> "$LOG" 2>&1 ;;
    esac
    rm -f "$PID_FILE"
fi

# Clean up older releases if they were installed before this version.
if command -v crontab >/dev/null 2>&1; then
    crontab -l 2>/dev/null | grep -v "$BASE/worker.sh" > "$CRON_FILE"
    crontab "$CRON_FILE" >> "$LOG" 2>&1
    rm -f "$CRON_FILE"
fi

pkill -f "$BASE/scheduler.sh" >> "$LOG" 2>&1
pkill -f "$BASE/worker.sh" >> "$LOG" 2>&1
lipc-set-prop com.lab126.cmd wirelessEnable 0 >> "$LOG" 2>&1
lipc-set-prop com.lab126.powerd preventScreenSaver 0 >> "$LOG" 2>&1

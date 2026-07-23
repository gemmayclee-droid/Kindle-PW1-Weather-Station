#!/bin/sh

BASE="/mnt/us/extensions/weatheriot"
LOG="$BASE/log.txt"

cd "$BASE" || exit 1

INTERVAL=$(grep "<interval>" config.xml | sed 's/.*<interval>\(.*\)<\/interval>.*/\1/' | tr -d '\r' | tr -d ' ')

case "$INTERVAL" in
    *[!0-9]*|"")
        INTERVAL=14400
        ;;
esac

HOURS=$((INTERVAL / 3600))

if [ "$HOURS" -lt 1 ]; then
    HOURS=4
fi

echo "=== 安裝省電定時更新: $(date) ===" >> "$LOG"
echo "更新間隔: $HOURS 小時" >> "$LOG"
echo "使用內建 scheduler，不依賴 crontab" >> "$LOG"

# 停掉舊版常駐 worker 或 scheduler，避免重複更新與耗電。
pkill -f "$BASE/scheduler.sh" >> "$LOG" 2>&1
pkill -f "$BASE/worker.sh" >> "$LOG" 2>&1

echo "立即執行第一次更新..." >> "$LOG"
/bin/sh "$BASE/worker.sh" >> "$LOG" 2>&1

/bin/sh "$BASE/scheduler.sh" sleep-first >> "$LOG" 2>&1 &

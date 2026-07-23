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

if [ "$INTERVAL" -lt 3600 ]; then
    INTERVAL=14400
fi

echo "=== scheduler 啟動: $(date) ===" >> "$LOG"
echo "scheduler 更新間隔: $INTERVAL 秒" >> "$LOG"

if [ "$1" = "sleep-first" ]; then
    echo "scheduler 先休眠 $INTERVAL 秒" >> "$LOG"
    sleep "$INTERVAL"
fi

while true; do
    echo "=== scheduler 觸發更新: $(date) ===" >> "$LOG"
    /bin/sh "$BASE/worker.sh" >> "$LOG" 2>&1
    echo "scheduler 休眠 $INTERVAL 秒" >> "$LOG"
    sleep "$INTERVAL"
done

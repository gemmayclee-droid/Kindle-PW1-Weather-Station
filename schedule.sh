#!/bin/sh

BASE="/mnt/us/extensions/weatheriot"
LOG="$BASE/log.txt"
CRON_FILE="/tmp/weatheriot.cron"
JOB="/bin/sh $BASE/worker.sh >> $LOG 2>&1"

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

# 停掉舊版常駐 worker 或 fallback scheduler，避免重複更新與耗電。
pkill -f "$BASE/scheduler.sh" >> "$LOG" 2>&1
pkill -f "$BASE/worker.sh" >> "$LOG" 2>&1

if command -v crontab >/dev/null 2>&1; then
    crontab -l 2>/dev/null | grep -v "$BASE/worker.sh" > "$CRON_FILE"
    echo "0 */$HOURS * * * $JOB" >> "$CRON_FILE"
    crontab "$CRON_FILE" >> "$LOG" 2>&1
    rm -f "$CRON_FILE"

    if command -v crond >/dev/null 2>&1; then
        if ! pidof crond >/dev/null 2>&1; then
            crond >> "$LOG" 2>&1
        fi
    fi

    echo "cron 定時更新已安裝" >> "$LOG"
else
    echo "找不到 crontab，改用 fallback scheduler" >> "$LOG"
    /bin/sh "$BASE/scheduler.sh" >> "$LOG" 2>&1 &
fi

# 安裝排程後立即前台更新一次，確保 KUAL 執行後畫面會馬上變化。
echo "立即執行第一次更新..." >> "$LOG"
/bin/sh "$BASE/worker.sh" >> "$LOG" 2>&1

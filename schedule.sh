#!/bin/sh

BASE="/mnt/us/extensions/weatheriot"
LOG="$BASE/log.txt"
PID_FILE="$BASE/schedule.pid"

cd "$BASE" || exit 1

read_interval() {
    INTERVAL=$(grep "<interval>" config.xml | sed 's/.*<interval>\(.*\)<\/interval>.*/\1/' | tr -d '\r' | tr -d ' ')

    case "$INTERVAL" in
        *[!0-9]*|"")
            INTERVAL=14400
            ;;
    esac

    if [ "$INTERVAL" -lt 3600 ]; then
        INTERVAL=14400
    fi
}

stop_old_jobs() {
    if [ -f "$PID_FILE" ]; then
        OLD_PID=$(cat "$PID_FILE" 2>/dev/null)
        case "$OLD_PID" in
            *[!0-9]*|"") ;;
            *) kill "$OLD_PID" >> "$LOG" 2>&1 ;;
        esac
        rm -f "$PID_FILE"
    fi

    # Clean up legacy versions and in-flight refreshes.
    pkill -f "$BASE/scheduler.sh" >> "$LOG" 2>&1
    pkill -f "$BASE/worker.sh" >> "$LOG" 2>&1
}

if [ "$1" = "run" ]; then
    echo $$ > "$PID_FILE"
    read_interval
    echo "=== 內建 schedule loop 啟動: $(date) ===" >> "$LOG"
    echo "schedule 更新間隔: $INTERVAL 秒" >> "$LOG"

    while true; do
        sleep "$INTERVAL"
        echo "=== schedule 觸發更新: $(date) ===" >> "$LOG"
        /bin/sh "$BASE/worker.sh" >> "$LOG" 2>&1
    done
fi

read_interval
HOURS=$((INTERVAL / 3600))

if [ "$HOURS" -lt 1 ]; then
    HOURS=4
fi

echo "=== 安裝省電定時更新: $(date) ===" >> "$LOG"
echo "更新間隔: $HOURS 小時" >> "$LOG"
echo "使用 schedule.sh 內建循環，不依賴 crontab" >> "$LOG"

stop_old_jobs

echo "立即執行第一次更新..." >> "$LOG"
/bin/sh "$BASE/worker.sh" >> "$LOG" 2>&1

/bin/sh "$BASE/schedule.sh" run >> "$LOG" 2>&1 &

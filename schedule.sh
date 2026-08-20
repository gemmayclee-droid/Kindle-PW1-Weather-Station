#!/bin/sh

BASE="/mnt/us/extensions/weatheriot"
LOG="$BASE/log.txt"
PID_FILE="$BASE/schedule.pid"
CRON_FILE="/tmp/weatheriot.cron"

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

read_hour_setting() {
    TAG="$1"
    DEFAULT="$2"
    VALUE=$(grep "<$TAG>" config.xml | sed "s/.*<$TAG>\(.*\)<\/$TAG>.*/\1/" | tr -d '\r' | tr -d ' ')

    case "$VALUE" in
        *[!0-9]*|"")
            VALUE="$DEFAULT"
            ;;
    esac

    if [ "$VALUE" -lt 0 ] || [ "$VALUE" -gt 23 ]; then
        VALUE="$DEFAULT"
    fi

    echo "$VALUE"
}

is_sleep_window() {
    HOUR=$(date +%H | sed 's/^0//')
    if [ -z "$HOUR" ]; then
        HOUR=0
    fi

    SLEEP_START=$(read_hour_setting sleepStart 22)
    SLEEP_END=$(read_hour_setting sleepEnd 7)

    if [ "$SLEEP_START" -eq "$SLEEP_END" ]; then
        return 1
    fi

    if [ "$SLEEP_START" -lt "$SLEEP_END" ]; then
        [ "$HOUR" -ge "$SLEEP_START" ] && [ "$HOUR" -lt "$SLEEP_END" ]
    else
        [ "$HOUR" -ge "$SLEEP_START" ] || [ "$HOUR" -lt "$SLEEP_END" ]
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

    pkill -f "$BASE/scheduler.sh" >> "$LOG" 2>&1
    pkill -f "$BASE/schedule.sh run" >> "$LOG" 2>&1
    pkill -f "$BASE/worker.sh" >> "$LOG" 2>&1

    if command -v crontab >/dev/null 2>&1; then
        crontab -l 2>/dev/null | grep -v "$BASE/worker.sh" > "$CRON_FILE"
        crontab "$CRON_FILE" >> "$LOG" 2>&1
        rm -f "$CRON_FILE"
    fi
}

if [ "$1" = "run" ]; then
    echo $$ > "$PID_FILE"
    read_interval
    echo "=== 4 小時背景循環啟動: $(date) ===" >> "$LOG"
    echo "schedule pid: $$" >> "$LOG"
    echo "更新間隔: $INTERVAL 秒" >> "$LOG"

    while true; do
        read_interval
        if is_sleep_window; then
            echo "=== 夜間省電時段，跳過天氣更新: $(date) ===" >> "$LOG"
            echo "不開啟 WiFi，不執行 render.py，30 分鐘後重新檢查..." >> "$LOG"
            sleep 1800
        else
            echo "=== schedule 觸發更新: $(date) ===" >> "$LOG"
            /bin/sh "$BASE/worker.sh" >> "$LOG" 2>&1
            read_interval
            echo "保持 weather.png，$INTERVAL 秒後更新..." >> "$LOG"
            sleep "$INTERVAL"
        fi
    done
fi

read_interval

echo "=== 安裝 4 小時定時更新: $(date) ===" >> "$LOG"
echo "更新間隔: $INTERVAL 秒" >> "$LOG"
echo "省電睡眠時段: $(read_hour_setting sleepStart 22):00-$(read_hour_setting sleepEnd 7):00" >> "$LOG"
echo "使用 schedule.sh 背景循環，不依賴 crontab" >> "$LOG"

stop_old_jobs

/bin/sh "$BASE/schedule.sh" run >> "$LOG" 2>&1 &
echo $! > "$PID_FILE"
NEW_PID=$(cat "$PID_FILE" 2>/dev/null)
echo "schedule.sh 背景循環已啟動 pid=$NEW_PID" >> "$LOG"
echo "第一次更新會立即執行；夜間省電時段會跳過更新" >> "$LOG"

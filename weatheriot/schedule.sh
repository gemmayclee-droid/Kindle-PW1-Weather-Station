#!/bin/sh

BASE="/mnt/us/extensions/weatheriot"
LOG="$BASE/log.txt"
PID_FILE="$BASE/schedule.pid"
CRON_FILE="/tmp/weatheriot.cron"

cd "$BASE" || exit 1

read_time_number() {
    VALUE=$(date "$1" | sed 's/^0//')
    if [ -z "$VALUE" ]; then
        VALUE=0
    fi
    echo "$VALUE"
}

seconds_until_next_slot() {
    WEEKDAY=$(date +%w)
    HOUR=$(read_time_number +%H)
    MINUTE=$(read_time_number +%M)
    SECOND=$(read_time_number +%S)
    DAYS=0
    TARGET_HOUR=8

    case "$WEEKDAY" in
        6)
            DAYS=2
            ;;
        0)
            DAYS=1
            ;;
        *)
            if [ "$HOUR" -lt 8 ]; then
                TARGET_HOUR=8
            elif [ "$HOUR" -lt 12 ]; then
                TARGET_HOUR=12
            elif [ "$HOUR" -lt 16 ]; then
                TARGET_HOUR=16
            elif [ "$HOUR" -lt 20 ]; then
                TARGET_HOUR=20
            elif [ "$WEEKDAY" -eq 5 ]; then
                DAYS=3
            else
                DAYS=1
            fi
            ;;
    esac

    WAIT=$((DAYS * 86400 + (TARGET_HOUR - HOUR) * 3600 - MINUTE * 60 - SECOND))
    if [ "$WAIT" -le 0 ]; then
        WAIT=60
    fi
    echo "$WAIT"
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
    echo "=== 工作日背景排程啟動: $(date) ===" >> "$LOG"
    echo "schedule pid: $$" >> "$LOG"
    echo "更新時段: 週一至週五 08:00、12:00、16:00、20:00" >> "$LOG"
    echo "自動更新期間保持 Kindle 喚醒，避免背景排程在休眠後停止" >> "$LOG"
    lipc-set-prop com.lab126.powerd preventScreenSaver 1 >> "$LOG" 2>&1

    while true; do
        WAIT=$(seconds_until_next_slot)
        echo "距離下一次工作日更新: $WAIT 秒" >> "$LOG"
        sleep "$WAIT"
        echo "=== schedule 觸發更新: $(date) ===" >> "$LOG"
        /bin/sh "$BASE/worker.sh" --scheduled >> "$LOG" 2>&1
        # 即使本輪天氣下載失敗，也不能讓螢幕保護中斷下一輪排程。
        lipc-set-prop com.lab126.powerd preventScreenSaver 1 >> "$LOG" 2>&1
    done
fi

echo "=== 安裝工作日定時更新: $(date) ===" >> "$LOG"
echo "更新時段: 週一至週五 08:00、12:00、16:00、20:00" >> "$LOG"
echo "使用 schedule.sh 背景循環，不依賴 crontab" >> "$LOG"

stop_old_jobs

/bin/sh "$BASE/schedule.sh" run >> "$LOG" 2>&1 &
echo $! > "$PID_FILE"
NEW_PID=$(cat "$PID_FILE" 2>/dev/null)
echo "schedule.sh 背景循環已啟動 pid=$NEW_PID" >> "$LOG"
echo "下一次更新會在下一個工作日時段執行；自動更新期間不會進入休眠" >> "$LOG"

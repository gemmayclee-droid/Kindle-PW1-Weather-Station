#!/bin/sh

BASE="/mnt/us/extensions/weatheriot"
cd "$BASE"

LOG="$BASE/log.txt"
IMG="$BASE/weather.png"

echo "===================================" >> "$LOG"
echo " PW1 Weather Kiosk Mode " >> "$LOG"
echo "===================================" >> "$LOG"

# ==================================================
# 初始化
# ==================================================

# 關前燈
lipc-set-prop com.lab126.powerd flIntensity 0 >> "$LOG" 2>&1
# 某些 FW 還需要這個
lipc-set-prop com.lab126.powerd frontlight 0 >> "$LOG" 2>&1
# 關閉 frontlight daemon
killall ftlight >> "$LOG" 2>&1

# CPU powersave
if [ -e /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]; then
    echo powersave > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>> "$LOG"
fi

# 禁止 Kindle screensaver（超重要）
lipc-set-prop com.lab126.powerd preventScreenSaver 1 >> "$LOG" 2>&1

# 初始關 WiFi
lipc-set-prop com.lab126.cmd wirelessEnable 0 >> "$LOG" 2>&1

REFRESH_COUNT=0

while true; do

    echo "" >> "$LOG"
    echo "--- 更新開始 $(date) ---" >> "$LOG"

    # ==================================================
    # 開 WiFi
    # ==================================================

    echo "開啟 WiFi..." >> "$LOG"

    lipc-set-prop com.lab126.cmd wirelessEnable 1 >> "$LOG" 2>&1

    # 等待 WiFi 真正連線
    COUNT=0
    while [ $COUNT -lt 20 ]; do
        if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
            echo "WiFi 已連線" >> "$LOG"
            break
        fi
        sleep 2
        COUNT=$((COUNT + 1))
    done

    if ! ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        echo "WiFi 連線失敗，重置 WiFi..." >> "$LOG"
        lipc-set-prop com.lab126.cmd wirelessEnable 0 >> "$LOG" 2>&1
        sleep 5
        lipc-set-prop com.lab126.cmd wirelessEnable 1 >> "$LOG" 2>&1
        sleep 15
    fi

    # ==================================================
    # 讀設定
    # ==================================================

    CITY=$(grep "<city>" config.xml | sed 's/.*<city>\(.*\)<\/city>.*/\1/' | tr -d '\r' | tr -d ' ')
    APIKEY=$(grep "<apikey>" config.xml | sed 's/.*<apikey>\(.*\)<\/apikey>.*/\1/' | tr -d '\r' | tr -d ' ')

    echo "城市: $CITY" >> "$LOG"

    # ==================================================
    # 更新圖片
    # ==================================================

    echo "render.py 開始時間: $(date)" >> "$LOG"
    START_TS=$(date +%s)
    timeout -t 120 /usr/bin/python3 render.py "$CITY" "$APIKEY" >> "$LOG" 2>&1
    RET=$?
    END_TS=$(date +%s)
    echo "render.py 結束時間: $(date)" >> "$LOG"
    echo "render.py 執行秒數: $((END_TS - START_TS)) 秒" >> "$LOG"
    echo "render.py return code: $RET" >> "$LOG"

    killall python3 >> "$LOG" 2>&1

    # ==================================================
    # 關 WiFi（超重要）
    # ==================================================

    echo "關閉 WiFi..." >> "$LOG"

    lipc-set-prop com.lab126.cmd wirelessEnable 0 >> "$LOG" 2>&1

    sleep 3

    # ==================================================
    # 顯示圖片
    # ==================================================

    if [ -f "$IMG" ]; then

        echo "更新 EINK..." >> "$LOG"
        # 不每次 full refresh，避免耗電與閃爍
        # 每 3 次做一次 full refresh
        REFRESH_COUNT=$((REFRESH_COUNT + 1))
        if [ $REFRESH_COUNT -ge 3 ]; then
            echo "執行 full refresh 清除殘影..." >> "$LOG"
            /usr/sbin/eips -c >> "$LOG" 2>&1
            sleep 1
            /usr/sbin/eips -g "$IMG" >> "$LOG" 2>&1
            REFRESH_COUNT=0
        else
            /usr/sbin/eips -g "$IMG" >> "$LOG" 2>&1
        fi
        echo "weather.png 顯示完成" >> "$LOG"
    else
        echo "ERROR: weather.png 不存在" >> "$LOG"
    fi

    # ==================================================
    # 降低 Java UI 優先權
    # ==================================================

    CVM_PID=$(pidof cvm)

    if [ ! -z "$CVM_PID" ]; then
        renice 19 $CVM_PID >> "$LOG" 2>&1
    fi

    PILLOW_PID=$(pidof pillowd)

    if [ ! -z "$PILLOW_PID" ]; then
        renice 19 $PILLOW_PID >> "$LOG" 2>&1
    fi

    # 關閉沒用 renderer
    killall webreader >> "$LOG" 2>&1
    killall mesquite >> "$LOG" 2>&1

    echo "保持 weather.png 3小時後更新..." >> "$LOG"

    # ==================================================
    # 等待下一次更新
    # ==================================================

    sleep 10800

done
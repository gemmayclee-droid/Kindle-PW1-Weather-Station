#!/bin/sh

BASE="/mnt/us/extensions/weatheriot"
cd "$BASE"

LOG="$BASE/log.txt"
IMG="$BASE/weather.png"

echo "===================================" >> "$LOG"
echo " PW1 Weather Single Refresh " >> "$LOG"
echo "===================================" >> "$LOG"

cleanup() {
    echo "清理省電狀態..." >> "$LOG"
    lipc-set-prop com.lab126.cmd wirelessEnable 0 >> "$LOG" 2>&1
    lipc-set-prop com.lab126.powerd preventScreenSaver 0 >> "$LOG" 2>&1
}

trap cleanup EXIT INT TERM

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

# 只在本次更新期間禁止 screensaver，結束後會恢復，避免長時間耗電。
lipc-set-prop com.lab126.powerd preventScreenSaver 1 >> "$LOG" 2>&1

# 初始關 WiFi
lipc-set-prop com.lab126.cmd wirelessEnable 0 >> "$LOG" 2>&1

echo "" >> "$LOG"
echo "--- 更新開始 $(date) ---" >> "$LOG"

# ==================================================
# 開 WiFi
# ==================================================

echo "開啟 WiFi..." >> "$LOG"

lipc-set-prop com.lab126.cmd wirelessEnable 1 >> "$LOG" 2>&1

# 等待 WiFi 真正連線。省電優先，避免一次更新把 WiFi 開太久。
COUNT=0
WIFI_OK=0
while [ $COUNT -lt 10 ]; do
    if ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; then
        echo "WiFi 已連線" >> "$LOG"
        WIFI_OK=1
        break
    fi
    sleep 2
    COUNT=$((COUNT + 1))
done

if [ "$WIFI_OK" -ne 1 ]; then
    echo "WiFi 連線失敗，本次跳過網路更新" >> "$LOG"
fi

# ==================================================
# 讀設定
# ==================================================

CITY=$(grep "<city>" config.xml | sed 's/.*<city>\(.*\)<\/city>.*/\1/' | tr -d '\r' | tr -d ' ')
LAT=$(grep "<lat>" config.xml | sed 's/.*<lat>\(.*\)<\/lat>.*/\1/' | tr -d '\r' | tr -d ' ')
LON=$(grep "<lon>" config.xml | sed 's/.*<lon>\(.*\)<\/lon>.*/\1/' | tr -d '\r' | tr -d ' ')
APIKEY=$(grep "<apikey>" config.xml | sed 's/.*<apikey>\(.*\)<\/apikey>.*/\1/' | tr -d '\r' | tr -d ' ')

echo "城市: $CITY" >> "$LOG"
echo "座標: $LAT,$LON" >> "$LOG"

# ==================================================
# 更新圖片
# ==================================================

echo "render.py 開始時間: $(date)" >> "$LOG"
START_TS=$(date +%s)
if [ "$WIFI_OK" -eq 1 ]; then
    timeout -t 45 /usr/bin/python3 render.py "$CITY" "$APIKEY" "$LAT" "$LON" >> "$LOG" 2>&1
    RET=$?
else
    RET=0
fi
END_TS=$(date +%s)
echo "render.py 結束時間: $(date)" >> "$LOG"
echo "render.py 執行秒數: $((END_TS - START_TS)) 秒" >> "$LOG"
echo "render.py return code: $RET" >> "$LOG"

if [ $RET -eq 124 ]; then
    killall python3 >> "$LOG" 2>&1
fi

# ==================================================
# 關 WiFi（超重要）
# ==================================================

echo "關閉 WiFi..." >> "$LOG"
lipc-set-prop com.lab126.cmd wirelessEnable 0 >> "$LOG" 2>&1

# ==================================================
# 顯示圖片
# ==================================================

if [ -f "$IMG" ]; then
    echo "更新 EINK..." >> "$LOG"
    /usr/sbin/eips -g "$IMG" >> "$LOG" 2>&1
    echo "weather.png 顯示完成" >> "$LOG"
else
    echo "ERROR: weather.png 不存在" >> "$LOG"
fi

echo "單次更新完成，worker 結束，交回 Kindle 休眠" >> "$LOG"

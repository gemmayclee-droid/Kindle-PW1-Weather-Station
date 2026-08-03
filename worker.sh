#!/bin/sh

BASE="/mnt/us/extensions/weatheriot"
cd "$BASE" || exit 1

LOG="$BASE/log.txt"
IMG="$BASE/weather.png"
VERSION="worker-once-2026-08-03"
KEEP_DISPLAY=0

cleanup_power() {
    echo "清理省電狀態..." >> "$LOG"
    lipc-set-prop com.lab126.cmd wirelessEnable 0 >> "$LOG" 2>&1
    if [ "$KEEP_DISPLAY" -eq 1 ]; then
        echo "保持螢幕保護關閉，避免 weather.png 被覆蓋" >> "$LOG"
        lipc-set-prop com.lab126.powerd preventScreenSaver 1 >> "$LOG" 2>&1
    else
        lipc-set-prop com.lab126.powerd preventScreenSaver 0 >> "$LOG" 2>&1
    fi
}

image_info() {
    if [ -f "$IMG" ]; then
        SIZE=$(wc -c < "$IMG" 2>/dev/null)
        MTIME=$(ls -l "$IMG" 2>/dev/null)
        echo "weather.png size: $SIZE bytes" >> "$LOG"
        echo "weather.png file: $MTIME" >> "$LOG"
    else
        echo "weather.png status: missing" >> "$LOG"
    fi
}

trap cleanup_power EXIT INT TERM

echo "===================================" >> "$LOG"
echo " PW1 Weather Single Refresh " >> "$LOG"
echo " version: $VERSION " >> "$LOG"
echo "===================================" >> "$LOG"
echo "--- 更新開始 $(date) ---" >> "$LOG"

echo "更新前圖片狀態:" >> "$LOG"
image_info

# 更新成功後會保持 screensaver 關閉，避免 weather.png 被覆蓋。
lipc-set-prop com.lab126.powerd preventScreenSaver 1 >> "$LOG" 2>&1
lipc-set-prop com.lab126.powerd flIntensity 0 >> "$LOG" 2>&1
lipc-set-prop com.lab126.powerd frontlight 0 >> "$LOG" 2>&1
killall ftlight >> "$LOG" 2>&1

if [ -e /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]; then
    echo powersave > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>> "$LOG"
fi

echo "開啟 WiFi..." >> "$LOG"
lipc-set-prop com.lab126.cmd wirelessEnable 1 >> "$LOG" 2>&1

COUNT=0
WIFI_OK=0
while [ $COUNT -lt 10 ]; do
    if ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; then
        echo "WiFi ping 已連線" >> "$LOG"
        WIFI_OK=1
        break
    fi
    sleep 2
    COUNT=$((COUNT + 1))
done

if [ "$WIFI_OK" -ne 1 ]; then
    echo "WiFi ping 檢查失敗，仍嘗試 HTTPS 天氣更新" >> "$LOG"
fi

CITY=$(grep "<city>" config.xml | sed 's/.*<city>\(.*\)<\/city>.*/\1/' | tr -d '\r' | tr -d ' ')
LAT=$(grep "<lat>" config.xml | sed 's/.*<lat>\(.*\)<\/lat>.*/\1/' | tr -d '\r' | tr -d ' ')
LON=$(grep "<lon>" config.xml | sed 's/.*<lon>\(.*\)<\/lon>.*/\1/' | tr -d '\r' | tr -d ' ')
LANGUAGE=$(grep "<lang>" config.xml | sed 's/.*<lang>\(.*\)<\/lang>.*/\1/' | tr -d '\r' | tr -d ' ')

if [ -z "$LANGUAGE" ]; then
    LANGUAGE="zh"
fi

echo "城市: $CITY" >> "$LOG"
echo "座標: $LAT,$LON" >> "$LOG"
echo "語言: $LANGUAGE" >> "$LOG"

echo "render.py 開始時間: $(date)" >> "$LOG"
START_TS=$(date +%s)
timeout -t 60 /usr/bin/python3 render.py "$CITY" "$LAT" "$LON" "$LANGUAGE" >> "$LOG" 2>&1
RET=$?
END_TS=$(date +%s)
echo "render.py 結束時間: $(date)" >> "$LOG"
echo "render.py 執行秒數: $((END_TS - START_TS)) 秒" >> "$LOG"
echo "render.py return code: $RET" >> "$LOG"

if [ $RET -eq 124 ]; then
    echo "render.py timeout，清理 python3" >> "$LOG"
    killall python3 >> "$LOG" 2>&1
fi

echo "關閉 WiFi..." >> "$LOG"
lipc-set-prop com.lab126.cmd wirelessEnable 0 >> "$LOG" 2>&1

echo "更新後圖片狀態:" >> "$LOG"
image_info

if [ $RET -eq 0 ] && [ -f "$IMG" ]; then
    echo "更新 EINK..." >> "$LOG"
    lipc-set-prop com.lab126.powerd preventScreenSaver 1 >> "$LOG" 2>&1
    /usr/sbin/eips -g "$IMG" >> "$LOG" 2>&1
    KEEP_DISPLAY=1
    echo "weather.png 顯示完成" >> "$LOG"
else
    echo "ERROR: render.py 未成功，跳過 EINK 顯示，避免顯示舊圖" >> "$LOG"
fi

cleanup_power
echo "--- 更新結束 $(date) ---" >> "$LOG"
if [ "$KEEP_DISPLAY" -eq 1 ]; then
    echo "單次更新完成，保持 weather.png 顯示" >> "$LOG"
else
    echo "單次更新失敗，worker 結束並恢復螢幕保護" >> "$LOG"
fi

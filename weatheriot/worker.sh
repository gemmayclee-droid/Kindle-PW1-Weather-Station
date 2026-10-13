#!/bin/sh

BASE="/mnt/us/extensions/weatheriot"
cd "$BASE" || exit 1

LOG="$BASE/log.txt"
IMG="$BASE/weather.png"
VERSION="worker-once-2026-10-13"
KEEP_DISPLAY=0
SCHEDULED=0
NETWORK_ATTEMPTS=8
NETWORK_DELAY=3
NETWORK_PROBE_TIMEOUT=8
NETWORK_STABLE_SUCCESSES=2
NETWORK_RECOVERY_DELAY=10
RENDER_TIMEOUT=90

if [ "$1" = "--scheduled" ]; then
    SCHEDULED=1
    KEEP_DISPLAY=1
fi

cleanup_power() {
    echo "清理省電狀態..." >> "$LOG"
    lipc-set-prop com.lab126.cmd wirelessEnable 0 >> "$LOG" 2>&1
    if [ "$KEEP_DISPLAY" -eq 1 ]; then
        echo "保持螢幕保護關閉，避免 weather.png 被覆蓋" >> "$LOG"
        lipc-set-prop com.lab126.powerd preventScreenSaver 1 >> "$LOG" 2>&1
    else
        echo "允許螢幕保護與休眠以節省電力" >> "$LOG"
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

wait_for_network() {
    ATTEMPT=1
    STABLE_SUCCESSES=0
    while [ "$ATTEMPT" -le "$NETWORK_ATTEMPTS" ]; do
        # 只解析 DNS 不代表後續 HTTPS 還能連線。以實際 API TLS 連線驗證，
        # 並要求連續兩次成功，避免 PW1 剛從休眠醒來時的短暫假陽性。
        if timeout -t "$NETWORK_PROBE_TIMEOUT" /usr/bin/python3 -c 'import requests; requests.get("https://api.open-meteo.com", timeout=5, verify=False)' >/dev/null 2>&1; then
            STABLE_SUCCESSES=$((STABLE_SUCCESSES + 1))
            echo "Open-Meteo HTTPS 連線成功（穩定檢查 $STABLE_SUCCESSES/$NETWORK_STABLE_SUCCESSES；第 $ATTEMPT/$NETWORK_ATTEMPTS 次）" >> "$LOG"
            if [ "$STABLE_SUCCESSES" -ge "$NETWORK_STABLE_SUCCESSES" ]; then
                echo "WiFi、DNS 與 HTTPS 已穩定就緒" >> "$LOG"
                return 0
            fi
        else
            STABLE_SUCCESSES=0
            echo "等待 WiFi、DNS 與 HTTPS 就緒（第 $ATTEMPT/$NETWORK_ATTEMPTS 次檢查）" >> "$LOG"
        fi
        sleep "$NETWORK_DELAY"
        ATTEMPT=$((ATTEMPT + 1))
    done
    return 1
}

restart_wifi() {
    echo "WiFi／DNS 尚未就緒，重新啟動 WiFi 後再試一次" >> "$LOG"
    lipc-set-prop com.lab126.cmd wirelessEnable 0 >> "$LOG" 2>&1
    sleep 3
    lipc-set-prop com.lab126.cmd wirelessEnable 1 >> "$LOG" 2>&1
}

run_renderer() {
    echo "render.py 開始時間: $(date)" >> "$LOG"
    START_TS=$(date +%s)
    timeout -t "$RENDER_TIMEOUT" /usr/bin/python3 render.py "$CITY" "$LAT" "$LON" "$LANGUAGE" >> "$LOG" 2>&1
    RENDER_RET=$?
    END_TS=$(date +%s)
    echo "render.py 結束時間: $(date)" >> "$LOG"
    echo "render.py 執行秒數: $((END_TS - START_TS)) 秒" >> "$LOG"
    echo "render.py return code: $RENDER_RET" >> "$LOG"
    return "$RENDER_RET"
}

trap cleanup_power EXIT INT TERM

echo "===================================" >> "$LOG"
echo " PW1 Weather Single Refresh " >> "$LOG"
echo " version: $VERSION " >> "$LOG"
echo "===================================" >> "$LOG"
echo "--- 更新開始 $(date) ---" >> "$LOG"

echo "更新前圖片狀態:" >> "$LOG"
image_info

# 自動排程依賴常駐背景行程，不能讓 Kindle 進入會凍結行程的系統休眠。
lipc-set-prop com.lab126.powerd preventScreenSaver 1 >> "$LOG" 2>&1
lipc-set-prop com.lab126.powerd flIntensity 0 >> "$LOG" 2>&1
lipc-set-prop com.lab126.powerd frontlight 0 >> "$LOG" 2>&1
killall ftlight >> "$LOG" 2>&1

if [ -e /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]; then
    echo powersave > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>> "$LOG"
fi

echo "開啟 WiFi..." >> "$LOG"
lipc-set-prop com.lab126.cmd wirelessEnable 1 >> "$LOG" 2>&1

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

NETWORK_READY=0
if wait_for_network; then
    NETWORK_READY=1
else
    restart_wifi
    if wait_for_network; then
        NETWORK_READY=1
    fi
fi

if [ "$NETWORK_READY" -eq 1 ]; then
    run_renderer
    RET=$?

    # 即使 DNS 已回來，首次 HTTPS 連線仍可能因剛喚醒而失敗；只重試一次。
    if [ "$RET" -ne 0 ]; then
        echo "首次天氣更新失敗，等待 ${NETWORK_RECOVERY_DELAY} 秒讓網路穩定後重試一次" >> "$LOG"
        sleep "$NETWORK_RECOVERY_DELAY"
        restart_wifi
        if wait_for_network; then
            run_renderer
            RET=$?
        else
            RET=75
            echo "WiFi／DNS 在第二次等待後仍未就緒，略過天氣更新以節省電力" >> "$LOG"
        fi
    fi
else
    RET=75
    echo "WiFi／DNS 未就緒，略過天氣更新以節省電力" >> "$LOG"
fi

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
    echo "保持 weather.png 顯示與背景排程運作" >> "$LOG"
    echo "weather.png 顯示完成" >> "$LOG"
else
    echo "ERROR: render.py 未成功，跳過 EINK 顯示，避免顯示舊圖" >> "$LOG"
    if [ "$SCHEDULED" -eq 1 ]; then
        echo "自動排程模式：保留現有 weather.png 並維持螢幕保護關閉" >> "$LOG"
    fi
fi

cleanup_power
echo "--- 更新結束 $(date) ---" >> "$LOG"
if [ "$KEEP_DISPLAY" -eq 1 ]; then
    echo "單次更新完成，保持 weather.png 顯示" >> "$LOG"
else
    echo "手動單次更新未成功，允許 Kindle 休眠" >> "$LOG"
fi

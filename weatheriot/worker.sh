#!/bin/sh

BASE="/mnt/us/extensions/weatheriot"
cd "$BASE" || exit 1

LOG="$BASE/log.txt"
IMG="$BASE/weather.png"
VERSION="worker-once-2026-10-15.1"
KEEP_DISPLAY=0
SCHEDULED=0
NETWORK_ATTEMPTS=8
NETWORK_DELAY=3
RENDER_TIMEOUT=90
FORCED_DNS_SERVERS="223.5.5.5 119.29.29.29"

if [ "$1" = "--scheduled" ]; then
    SCHEDULED=1
    KEEP_DISPLAY=1
fi

enable_wifi() {
    # PW1 同時需要 cmd 與 wifid 兩個 LIPC 狀態為啟用；只設 wirelessEnable
    # 有時會讓 radio 開啟但 wifid 未重新建立 DHCP/DNS 連線。
    lipc-set-prop -i com.lab126.cmd wirelessEnable 1 >> "$LOG" 2>&1
    lipc-set-prop -i com.lab126.wifid enable 1 >> "$LOG" 2>&1
}

disable_wifi() {
    lipc-set-prop -i com.lab126.wifid enable 0 >> "$LOG" 2>&1
    lipc-set-prop -i com.lab126.cmd wirelessEnable 0 >> "$LOG" 2>&1
}

apply_forced_dns() {
    # wifid/DHCP 在每次喚醒後可能寫入不穩定的 DNS。將已驗證可連線的
    # 阿里與騰訊 DNS 寫入系統 resolver；每次更新都重設，避免被 DHCP 覆蓋。
    if ! mntroot rw >> "$LOG" 2>&1; then
        echo "ERROR: 無法將系統分割區切換為可寫，未套用指定 DNS" >> "$LOG"
        return 1
    fi

    {
        for DNS_SERVER in $FORCED_DNS_SERVERS; do
            echo "nameserver $DNS_SERVER"
        done
        echo "options timeout:2 attempts:2"
    } > /etc/resolv.conf
    DNS_RET=$?
    mntroot ro >> "$LOG" 2>&1

    if [ "$DNS_RET" -eq 0 ]; then
        echo "已套用指定 DNS：$FORCED_DNS_SERVERS" >> "$LOG"
    else
        echo "ERROR: 指定 DNS 寫入失敗" >> "$LOG"
    fi
    return "$DNS_RET"
}

cleanup_power() {
    echo "清理省電狀態..." >> "$LOG"
    disable_wifi
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
    DNS_REAPPLIED=0
    while [ "$ATTEMPT" -le "$NETWORK_ATTEMPTS" ]; do
        # PW1 的 HTTPS 預檢會偶發逾時，即使 render.py 隨後可正常更新；
        # 只做有限時的 DNS 查詢，讓實際天氣請求決定連線是否可用。
        if timeout -t 5 /usr/bin/python3 -c 'import socket; socket.gethostbyname("api.open-meteo.com")' >/dev/null 2>&1; then
            echo "WiFi 與 DNS 已就緒（第 $ATTEMPT/$NETWORK_ATTEMPTS 次檢查）" >> "$LOG"
            return 0
        else
            echo "等待 WiFi 與 DNS 就緒（第 $ATTEMPT/$NETWORK_ATTEMPTS 次檢查）" >> "$LOG"
            if [ "$ATTEMPT" -eq 4 ] && [ "$DNS_REAPPLIED" -eq 0 ]; then
                echo "DNS 持續未就緒，重新套用指定 DNS" >> "$LOG"
                apply_forced_dns
                DNS_REAPPLIED=1
            fi
        fi
        sleep "$NETWORK_DELAY"
        ATTEMPT=$((ATTEMPT + 1))
    done
    return 1
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
enable_wifi
# 先讓 wifid 完成 AP 關聯與 DHCP，之後再覆寫 resolver，避免 DHCP 立即蓋回 DNS。
sleep 10
apply_forced_dns

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
fi

if [ "$NETWORK_READY" -eq 1 ]; then
    run_renderer
    RET=$?
    if [ "$RET" -ne 0 ]; then
        echo "天氣更新失敗，安全結束本輪並交由 Online Screensaver 延後重試" >> "$LOG"
    fi
else
    RET=75
    echo "WiFi／DNS 未就緒，安全結束本輪並交由 Online Screensaver 延後重試" >> "$LOG"
fi

if [ $RET -eq 124 ]; then
    echo "render.py timeout，清理 python3" >> "$LOG"
    killall python3 >> "$LOG" 2>&1
fi

echo "關閉 WiFi..." >> "$LOG"
disable_wifi

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

echo "--- 更新結束 $(date) ---" >> "$LOG"
if [ "$KEEP_DISPLAY" -eq 1 ]; then
    echo "單次更新完成，保持 weather.png 顯示" >> "$LOG"
else
    echo "手動單次更新未成功，允許 Kindle 休眠" >> "$LOG"
fi

# 將網路／渲染失敗交給上層排程辨識，才能在 15 分鐘後建立新的更新程序重試。
exit "$RET"

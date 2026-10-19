#!/bin/sh

BASE="/mnt/us/extensions/weatheriot"
cd "$BASE" || exit 1

LOG="$BASE/log.txt"
IMG="$BASE/weather.png"
VERSION="worker-once-2026-10-19.1"
KEEP_DISPLAY=0
SCHEDULED=0
NETWORK_ATTEMPTS=8
NETWORK_DELAY=3
WIFI_STATE_ATTEMPTS=10
WIFI_STATE_DELAY=3
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
    if [ "${WEATHERIOT_POWER_MANAGED:-0}" = "1" ]; then
        echo "休眠由 Online Screensaver 接管，保持清醒以回傳更新結果" >> "$LOG"
    elif [ "$KEEP_DISPLAY" -eq 1 ]; then
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

wifi_state() {
    lipc-get-prop com.lab126.wifid cmState 2>/dev/null | tr -d '\r"'
}

wait_for_wifi_connection() {
    MAX_ATTEMPTS=$1
    ATTEMPT=1
    while [ "$ATTEMPT" -le "$MAX_ATTEMPTS" ]; do
        WIFI_STATE=$(wifi_state)
        if [ "$WIFI_STATE" = "CONNECTED" ]; then
            echo "WiFi 已連線（wifid cmState=CONNECTED，第 $ATTEMPT/$MAX_ATTEMPTS 次檢查）" >> "$LOG"
            return 0
        fi
        echo "等待 WiFi 實際連線（wifid cmState=${WIFI_STATE:-未知}，第 $ATTEMPT/$MAX_ATTEMPTS 次檢查）" >> "$LOG"
        sleep "$WIFI_STATE_DELAY"
        ATTEMPT=$((ATTEMPT + 1))
    done
    return 1
}

ensure_wifi_connection() {
    echo "啟用 WiFi，等待 Kindle 網路管理器確認連線..." >> "$LOG"
    enable_wifi
    if wait_for_wifi_connection "$WIFI_STATE_ATTEMPTS"; then
        return 0
    fi

    echo "WiFi 尚未連線，重置 wifid 與無線電後重新關聯" >> "$LOG"
    disable_wifi
    sleep 2
    enable_wifi
    if wait_for_wifi_connection 15; then
        return 0
    fi

    if command -v wpa_cli >/dev/null 2>&1; then
        echo "wifid 重啟後仍未連線，要求 wlan0 重新關聯" >> "$LOG"
        wpa_cli -i wlan0 reassociate >> "$LOG" 2>&1
        if wait_for_wifi_connection 10; then
            return 0
        fi
    fi

    WIFI_STATE=$(wifi_state)
    echo "ERROR: WiFi 無法建立連線（最後 wifid cmState=${WIFI_STATE:-未知}）" >> "$LOG"
    return 1
}

wait_for_network() {
    ATTEMPT=1
    while [ "$ATTEMPT" -le "$NETWORK_ATTEMPTS" ]; do
        # 不使用 libc gethostbyname：PW1 從 RTC 喚醒後偶爾會卡在系統 resolver，
        # 連外層 timeout 也無法及時讓 scheduler 繼續。直接向指定 DNS 發 UDP 查詢，
        # 並由 socket timeout 確保每次檢查都有明確上限。
        if /usr/bin/python3 -c '
import random, socket, struct, sys
name = "api.open-meteo.com"
query_id = random.randrange(65536)
encoded = b"".join(bytes([len(label)]) + label.encode("ascii") for label in name.split(".")) + b"\0"
packet = struct.pack("!HHHHHH", query_id, 0x0100, 1, 0, 0, 0) + encoded + struct.pack("!HH", 1, 1)
for server in sys.argv[1:]:
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sock.settimeout(2)
        sock.sendto(packet, (server, 53))
        response, _ = sock.recvfrom(512)
        sock.close()
        if len(response) >= 12:
            response_id, flags, questions, answers = struct.unpack("!HHHH", response[:8])
            if response_id == query_id and flags & 0x8000 and flags & 0x000F == 0 and answers > 0:
                sys.exit(0)
    except Exception:
        try:
            sock.close()
        except Exception:
            pass
sys.exit(1)
' $FORCED_DNS_SERVERS >/dev/null 2>&1; then
            echo "WiFi 與 DNS 已就緒（第 $ATTEMPT/$NETWORK_ATTEMPTS 次檢查）" >> "$LOG"
            return 0
        else
            echo "等待 WiFi 與 DNS 就緒（第 $ATTEMPT/$NETWORK_ATTEMPTS 次檢查）" >> "$LOG"
            if [ "$ATTEMPT" -eq 4 ]; then
                # 指定 DNS 已在本輪啟動時套用。PW1 在排程／休眠情境中重複
                # mntroot rw/ro 會偶發卡住，造成整個 scheduler 停止；因此
                # 不在這裡再次切換 rootfs，交由有限次檢查後的排程補救重試。
                echo "DNS 仍未就緒；避免重複切換系統分割區，本輪將交由排程補救重試" >> "$LOG"
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

ensure_wifi_connection
WIFI_RET=$?
if [ "$WIFI_RET" -eq 0 ]; then
    # 先等 wifid 回報實際連線，再覆寫 resolver，避免 DHCP 立即蓋回 DNS。
    sleep 3
    apply_forced_dns
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

NETWORK_READY=0
if [ "$WIFI_RET" -eq 0 ] && wait_for_network; then
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

#!/bin/sh
#
BOOT_LOG=/mnt/us/extensions/onlinescreensaver/onlinescreensaver.log
echo "$(date): 啟動前置記錄 $0" >> "$BOOT_LOG" 2>&1
##############################################################################
#
# Fetch weather screensaver from a configurable URL.

# change to directory of this script
cd "$(dirname "$0")"

# load configuration
if [ -e "config.sh" ]; then
	. /mnt/us/extensions/onlinescreensaver/bin/config.sh
else
	TMPFILE=/tmp/tmp.onlinescreensaver.png
fi

# load utils
if [ -e "utils.sh" ]; then
	. /mnt/us/extensions/onlinescreensaver/bin/utils.sh
else
	echo "在 `pwd` 找不到 utils.sh"
	exit
fi

setup_debug_log

# KUAL 可能快取新增的選單動作；若存在一次性診斷旗標，改由已知可執行的
# Update now 入口先收集 Linkss 系統狀態。成功後自動清除旗標。
LINKSS_DIAGNOSTIC_REQUEST=/mnt/us/extensions/onlinescreensaver/linkss-diagnostic.request
LINKSS_DIAGNOSTIC_LOG=/mnt/us/extensions/onlinescreensaver/linkss-diagnostic.log
if [ -f "$LINKSS_DIAGNOSTIC_REQUEST" ]; then
	/bin/sh /mnt/us/extensions/onlinescreensaver/bin/diagnose-linkss.sh
	if [ -s "$LINKSS_DIAGNOSTIC_LOG" ]; then
		rm -f "$LINKSS_DIAGNOSTIC_REQUEST"
		log_required "Linkss 診斷已完成"
	else
		log_required "Linkss 診斷未產生日誌"
	fi
fi

# 將新圖片寫入目前 PW1 使用的檔名，並同步舊版 PW 檔名，避免 Linkss 載入
# 舊圖片。兩個目標任一失敗時，保留明確錯誤日誌。
install_screensaver_image () {
	SOURCE_IMAGE=$1
	if ! cp "$SOURCE_IMAGE" "$SCREENSAVERFILE"; then
		log_required "無法寫入螢幕保護圖片：$SCREENSAVERFILE"
		return 1
	fi

	if [ -n "$SCREENSAVER_MIRROR_FILE" ] && [ "$SCREENSAVER_MIRROR_FILE" != "$SCREENSAVERFILE" ]; then
		if ! cp "$SOURCE_IMAGE" "$SCREENSAVER_MIRROR_FILE"; then
			log_required "無法同步螢幕保護圖片：$SCREENSAVER_MIRROR_FILE"
			return 1
		fi
	fi

	# Linkss 重新開機時會將多張圖片重新編號。同步所有已編號的 PW1
	# 圖片，避免輪播到上一輪留下的舊天氣圖。
	for EXISTING_IMAGE in "$SCREENSAVERFOLDER"/bg_ss*.png "$SCREENSAVERFOLDER"/bg_medium_ss*.png; do
		[ -f "$EXISTING_IMAGE" ] || continue
		if ! cp "$SOURCE_IMAGE" "$EXISTING_IMAGE"; then
			log_required "無法同步既有螢幕保護圖片：$EXISTING_IMAGE"
			return 1
		fi
	done

	return 0
}

# Online Screensaver 使用自己的 RTC 排程。若舊版 weatheriot 背景排程仍在，
# 將其停止並移除 PID，避免雙重更新與 preventScreenSaver 持續開啟。
WEATHERIOT_PID_FILE=/mnt/us/extensions/weatheriot/schedule.pid
WEATHERIOT_UNSCHEDULE=/mnt/us/extensions/weatheriot/unschedule.sh
if [ -f "$WEATHERIOT_PID_FILE" ]; then
	logger "偵測到舊 weatheriot 排程，正在停用"
	if [ -x "$WEATHERIOT_UNSCHEDULE" ]; then
		/bin/sh "$WEATHERIOT_UNSCHEDULE"
		if [ -f "$WEATHERIOT_PID_FILE" ]; then
			log_required "無法移除舊 weatheriot 排程 PID 檔"
		else
			log_required "已停用舊 weatheriot 排程，避免重複更新與耗電"
		fi
	else
		rm -f "$WEATHERIOT_PID_FILE"
		log_required "找不到 weatheriot 停用腳本，已移除舊排程 PID 檔"
	fi
fi

# Local weatheriot mode: render weather.png on the Kindle, then use it as
# the linkss screensaver image. This avoids requiring an HTTP image server.
trace "update.sh:29" "選擇更新模式；IMAGE_URI=${IMAGE_URI:-<空白>}"
if [ -z "$IMAGE_URI" ]; then
	trace "update.sh:31" "檢查本機 weatheriot 路徑"
	if [ -x "$LOCAL_WEATHER_SCRIPT" ] && [ -f "$LOCAL_WEATHER_IMAGE" -o -d "$(dirname "$LOCAL_WEATHER_IMAGE")" ]; then
		trace "update.sh:33" "執行 $LOCAL_WEATHER_SCRIPT"
		logger "IMAGE_URI 為空白，改用本機 weatheriot 產生圖片"
		/bin/sh "$LOCAL_WEATHER_SCRIPT"
		LOCAL_RET=$?
		# worker.sh 為獨立 weatheriot 排程而保留 preventScreenSaver；Online
		# Screensaver 已可使用 RTC 喚醒，因此此處必須恢復休眠能力。
		lipc-set-prop com.lab126.powerd preventScreenSaver 0
		POWER_RET=$?
		if [ "$POWER_RET" -ne 0 ]; then
			log_required "無法恢復 Kindle 休眠（preventScreenSaver=0，狀態碼 $POWER_RET）"
		else
			logger "已恢復 Kindle 休眠（preventScreenSaver=0）"
		fi
		trace "update.sh:36" "weatheriot worker 結束狀態碼=$LOCAL_RET"
		if [ "$LOCAL_RET" -eq 0 ] && [ -s "$LOCAL_WEATHER_IMAGE" ]; then
			trace "update.sh:38" "複製 $LOCAL_WEATHER_IMAGE 至 Linkss 螢幕保護圖片"
			if install_screensaver_image "$LOCAL_WEATHER_IMAGE"; then
				logger "本機 weatheriot 螢幕保護圖片已更新"
				trace "update.sh:41" "僅在螢幕保護啟用時重新整理畫面"
				lipc-get-prop com.lab126.powerd status | grep "Screen Saver" && (
					logger "正在更新螢幕上的圖片"
					eips -f -g "$SCREENSAVERFILE"
				)
			fi
		else
			log_required "本機 weatheriot 圖片產生失敗（狀態碼 $LOCAL_RET）"
		fi
	else
		trace "update.sh:49" "找不到本機 weatheriot 腳本或目錄"
		log_required "IMAGE_URI 為空白，且找不到本機 weatheriot 圖片產生器"
	fi
	exit 0
fi

# enable wireless if it is currently off
trace "update.sh:58" "使用遠端 IMAGE_URI 更新模式"
if [ 0 -eq `lipc-get-prop com.lab126.cmd wirelessEnable` ]; then
	logger "Wi-Fi 已關閉，正在開啟"
	lipc-set-prop com.lab126.cmd wirelessEnable 1
	DISABLE_WIFI=1
fi

# wait for network to be up
TIMER=${NETWORK_TIMEOUT}     # number of seconds to attempt a connection
CONNECTED=0                  # whether we are currently connected
while [ 0 -eq $CONNECTED ]; do
	# test whether we can ping outside
	/bin/ping -c 1 -w 2 $TEST_DOMAIN > /dev/null && CONNECTED=1

	# if we can't, checkout timeout or sleep for 1s
	if [ 0 -eq $CONNECTED ]; then
		TIMER=$(($TIMER-1))
		if [ 0 -eq $TIMER ]; then
			log_required "等待 ${NETWORK_TIMEOUT} 秒後仍無網際網路連線，停止本次更新。"
			break
		else
			sleep 1
		fi
	fi
done

if [ 1 -eq $CONNECTED ]; then
	trace "update.sh:82" "下載 $IMAGE_URI"
	if wget -q $IMAGE_URI -O $TMPFILE; then
		if install_screensaver_image "$TMPFILE"; then
			logger "螢幕保護圖片已更新"

			# refresh screen
			lipc-get-prop com.lab126.powerd status | grep "Screen Saver" && (
				logger "正在更新螢幕上的圖片"
				eips -f -g $SCREENSAVERFILE
			)
		fi
	else
		log_required "更新螢幕保護圖片時發生錯誤"
		if [ 1 -eq $DONOTRETRY ]; then
			touch $SCREENSAVERFILE
		fi
	fi
fi

# disable wireless if necessary
if [ 1 -eq $DISABLE_WIFI ]; then
	logger "正在關閉 Wi-Fi"
	lipc-set-prop com.lab126.cmd wirelessEnable 0
fi

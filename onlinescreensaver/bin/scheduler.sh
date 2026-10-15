#!/bin/sh
#
BOOT_LOG=/mnt/us/extensions/onlinescreensaver/onlinescreensaver.log
echo "$(date): 啟動前置記錄 $0" >> "$BOOT_LOG" 2>&1
##############################################################################
#
# 在設定的工作日時刻更新螢幕保護圖片。非更新時段只等待下一個時刻，不執行
# update.sh，以避免在夜間與週末喚醒 Wi-Fi 或產生圖片。

cd "$(dirname "$0")"

if [ -e "config.sh" ]; then
	. /mnt/us/extensions/onlinescreensaver/bin/config.sh
else
	WEEKDAY_UPDATE_TIMES="08:00 11:00 14:00 17:00 20:00"
	LOCAL_WEATHER_RETRY_COUNT=2
	LOCAL_WEATHER_RETRY_DELAY=900
	SCHEDULED_WIFI_WARMUP_SECONDS=60
	RTC=0
fi

if [ -e "utils.sh" ]; then
	. /mnt/us/extensions/onlinescreensaver/bin/utils.sh
else
	echo "在 `pwd` 找不到 utils.sh"
	exit 1
fi

setup_debug_log

# 回傳距離下一個工作日更新時刻的秒數。參數為 1 時，即使現在剛好在一個
# 更新時刻，也會尋找下一個時刻，避免完成更新後立刻重複執行。
seconds_to_next_update () {
	SKIP_CURRENT=${1:-0}
	WEEKDAY=$(date +%w) # 0=週日，1=週一，...，6=週六
	HOUR=$(date +%H)
	MINUTE=$(date +%M)
	HOUR=${HOUR#0}
	MINUTE=${MINUTE#0}
	[ -n "$HOUR" ] || HOUR=0
	[ -n "$MINUTE" ] || MINUTE=0
	CURRENT_MINUTE=$((HOUR * 60 + MINUTE))

	if [ "$WEEKDAY" -ge 1 ] && [ "$WEEKDAY" -le 5 ]; then
		for UPDATE_TIME in $WEEKDAY_UPDATE_TIMES; do
			UPDATE_HOUR=${UPDATE_TIME%:*}
			UPDATE_MINUTE=${UPDATE_TIME#*:}
			UPDATE_HOUR=${UPDATE_HOUR#0}
			UPDATE_MINUTE=${UPDATE_MINUTE#0}
			[ -n "$UPDATE_HOUR" ] || UPDATE_HOUR=0
			[ -n "$UPDATE_MINUTE" ] || UPDATE_MINUTE=0
			SLOT_MINUTE=$((UPDATE_HOUR * 60 + UPDATE_MINUTE))
			if [ "$CURRENT_MINUTE" -lt "$SLOT_MINUTE" ] || \
				{ [ "$SKIP_CURRENT" -eq 0 ] && [ "$CURRENT_MINUTE" -eq "$SLOT_MINUTE" ]; }; then
				echo $(( (SLOT_MINUTE - CURRENT_MINUTE) * 60 ))
				return
			fi
		done
	fi

	# 今日已無更新時刻，或今天是週末：計算下一個工作日的 08:00。
	case "$WEEKDAY" in
		0) DAYS_TO_MONDAY=1 ;;
		6) DAYS_TO_MONDAY=2 ;;
		5) DAYS_TO_MONDAY=3 ;;
		*) DAYS_TO_MONDAY=1 ;;
	esac
	echo $(( (DAYS_TO_MONDAY * 1440 - CURRENT_MINUTE + 480) * 60 ))
}

logger "工作日更新時刻：$WEEKDAY_UPDATE_TIMES（週六、週日不更新）"

# 排程由 RTC 從 Screen Saver 喚醒時，Wi-Fi 重新關聯與 DHCP 常比 shell
# 行程晚完成。先阻止再次休眠、啟用兩個 Wi-Fi 服務並等待一小段時間，讓
# weatheriot 開始 DNS 查詢時已有可用的網路；完成更新仍由 worker 關閉 Wi-Fi。
prepare_scheduled_network () {
	WARMUP_SECONDS=${SCHEDULED_WIFI_WARMUP_SECONDS:-60}
	case "$WARMUP_SECONDS" in
		''|*[!0-9]*) WARMUP_SECONDS=60 ;;
	esac

	lipc-set-prop com.lab126.powerd preventScreenSaver 1 >/dev/null 2>&1
	lipc-set-prop -i com.lab126.cmd wirelessEnable 1 >/dev/null 2>&1
	lipc-set-prop -i com.lab126.wifid enable 1 >/dev/null 2>&1
	log_required "排程喚醒後預熱 Wi-Fi ${WARMUP_SECONDS} 秒，等待 AP 關聯與 DHCP 完成"
	sleep "$WARMUP_SECONDS"
}

# 先等到下一個合法時刻，避免服務重啟時在非更新時段立刻更新。
INITIAL_WAIT=$(seconds_to_next_update 0)
if [ "$INITIAL_WAIT" -gt 0 ]; then
	logger "目前非更新時刻，下一次更新在 $((INITIAL_WAIT / 60)) 分鐘後"
	wait_for "$INITIAL_WAIT"
fi

while [ 1 -eq 1 ]; do
	logger "到達工作日更新時刻，開始更新螢幕保護圖片"
	UPDATE_ATTEMPT=0
	UPDATE_RET=1
	while [ "$UPDATE_ATTEMPT" -le "$LOCAL_WEATHER_RETRY_COUNT" ]; do
		prepare_scheduled_network
		/bin/sh ./update.sh
		UPDATE_RET=$?
		if [ "$UPDATE_RET" -eq 0 ]; then
			break
		fi

		UPDATE_ATTEMPT=$((UPDATE_ATTEMPT + 1))
		if [ "$UPDATE_ATTEMPT" -le "$LOCAL_WEATHER_RETRY_COUNT" ]; then
			log_required "天氣更新失敗（狀態碼 $UPDATE_RET），$LOCAL_WEATHER_RETRY_DELAY 秒後第 $UPDATE_ATTEMPT 次補救重試"
			wait_for "$LOCAL_WEATHER_RETRY_DELAY"
		fi
	done
	if [ "$UPDATE_RET" -ne 0 ]; then
		log_required "天氣更新已嘗試 $((LOCAL_WEATHER_RETRY_COUNT + 1)) 次仍失敗，等待下一個正式時段"
	fi

	NEXT_WAIT=$(seconds_to_next_update 1)
	logger "本次更新結束，下一次更新在 $((NEXT_WAIT / 60)) 分鐘後"
	wait_for "$NEXT_WAIT"
done

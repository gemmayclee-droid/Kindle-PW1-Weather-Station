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
	WEEKDAY_UPDATE_TIMES="08:00 10:00 12:00 14:00 16:00 18:00 20:00"
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

	# 今日已無更新時刻，或今天是週末：等待到下一個週一 08:00。
	case "$WEEKDAY" in
		0) DAYS_TO_MONDAY=1 ;;
		6) DAYS_TO_MONDAY=2 ;;
		*) DAYS_TO_MONDAY=$((8 - WEEKDAY)) ;;
	esac
	echo $(( (DAYS_TO_MONDAY * 1440 - CURRENT_MINUTE + 480) * 60 ))
}

logger "工作日更新時刻：$WEEKDAY_UPDATE_TIMES（週六、週日不更新）"

# 先等到下一個合法時刻，避免服務重啟時在非更新時段立刻更新。
INITIAL_WAIT=$(seconds_to_next_update 0)
if [ "$INITIAL_WAIT" -gt 0 ]; then
	logger "目前非更新時刻，下一次更新在 $((INITIAL_WAIT / 60)) 分鐘後"
	wait_for "$INITIAL_WAIT"
fi

while [ 1 -eq 1 ]; do
	logger "到達工作日更新時刻，開始更新螢幕保護圖片"
	/bin/sh ./update.sh

	NEXT_WAIT=$(seconds_to_next_update 1)
	logger "本次更新結束，下一次更新在 $((NEXT_WAIT / 60)) 分鐘後"
	wait_for "$NEXT_WAIT"
done

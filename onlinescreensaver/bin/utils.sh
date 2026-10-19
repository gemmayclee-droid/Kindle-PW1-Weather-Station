##############################################################################
# Logs a message to a log file (or to console if argument is /dev/stdout)

logger () {
	MSG=$1
	
	# do nothing if logging is not enabled
	if [ "x1" != "x$LOGGING" ]; then
		return
	fi

	# if no logfile is specified, set a default
	if [ -z $LOGFILE ]; then
		LOGFILE=/dev/stdout
	fi

	if [ "${DEBUG:-0}" -ge 1 ]; then
		echo `date`: $MSG >> $LOGFILE
	fi
}

log_required () {
	MSG=$1

	if [ "x1" != "x$LOGGING" ]; then
		return
	fi

	if [ -z "$LOGFILE" ]; then
		LOGFILE=/dev/stdout
	fi

	echo `date`: $MSG >> $LOGFILE
}

trace () {
	if [ "${DEBUG:-0}" -ge 2 ]; then
		log_required "追蹤 [$1] $2"
	fi
}

setup_debug_log () {
	if [ -z "$LOGFILE" ]; then
		return
	fi

	if [ -f "$LOGFILE" ] && [ "$(wc -c < "$LOGFILE")" -ge 262144 ]; then
		mv "$LOGFILE" "$LOGFILE.1"
	fi

	exec >> "$LOGFILE" 2>&1
	if [ "${DEBUG:-0}" -ge 2 ]; then
		# BusyBox ash on PW1 prints parameter expressions in PS4 literally.
		# Use explicit TRACE markers in callers for portable source locations.
		PS4='+ '
		set -x
	fi
	trap 'RESULT=$?; logger "=== Online Screensaver 已結束：$0（狀態碼 $RESULT）==="' 0
	logger "=== Online Screensaver 已啟動：$0 ==="
}


##############################################################################
# Retrieves the current time in seconds

currentTime () {
	date +%s
}


# runs when in the readyToSuspend state;
# sets the rtc to wake up
# arguments: $1 - amount of seconds to wake up in
set_rtc_wakeup()
{
	if lipc-set-prop -i com.lab126.powerd rtcWakeup "$1" 2>&1; then
		log_required "已設定 rtcWakeup，喚醒倒數：$1 秒"
	else
		log_required "ERROR: rtcWakeup 設定失敗，喚醒倒數：$1 秒"
	fi
}

##############################################################################
# sets an RTC alarm
# arguments: $1 - time in seconds from now

wait_for () {
	ENDWAIT=$(( $(currentTime) + $1 ))
	REMAININGWAITTIME=$(( $ENDWAIT - $(currentTime) ))
	logger "開始等待下一次更新：$1 秒"
	if [ "$REMAININGWAITTIME" -le 0 ]; then
		return
	fi
	log_required "進入電源事件等待，距離下次執行約 $REMAININGWAITTIME 秒"

	# 由背景助手延後釋放保護，讓主程序先進入 lipc-wait-event。不能由
	# 主程序同步解除：powerd 可能立刻休眠，使其來不及接收 readyToSuspend。
	(
		sleep 1
		lipc-set-prop com.lab126.powerd preventScreenSaver 0
	) &
	RELEASE_POWER_PID=$!

	# PW1 的 RTC 對多日鬧鐘不可靠。最長拆成六小時一段，週末也會定期
	# 重新設定下一段 RTC；裝置中途醒來時繼續等待，不能提早執行 update.sh。
	while [ $REMAININGWAITTIME -gt 0 ]; do
		CHUNKWAIT=$REMAININGWAITTIME
		if [ "$CHUNKWAIT" -gt 21600 ]; then
			CHUNKWAIT=21600
		fi
		EVENT=$(lipc-wait-event -s $CHUNKWAIT com.lab126.powerd readyToSuspend,wakeupFromSuspend,resuming)
		REMAININGWAITTIME=$(( $ENDWAIT - $(currentTime) ))
		logger "收到電源事件：$EVENT"

		case "$EVENT" in
			readyToSuspend*)
				# 事件可能在等待數小時後才出現，必須使用現在的剩餘時間。
				ALARM_WAIT=$REMAININGWAITTIME
				[ "$ALARM_WAIT" -gt 21600 ] && ALARM_WAIT=21600
				if [ "$ALARM_WAIT" -gt 0 ]; then
					set_rtc_wakeup "$ALARM_WAIT"
				fi
			;;
			wakeupFromSuspend*|resuming*)
				logger "裝置已喚醒，仍等待下一個排程時刻"
			;;
			*)
				logger "忽略電源事件：$EVENT"
			;;
		esac
	done
	wait "$RELEASE_POWER_PID"
	lipc-set-prop com.lab126.powerd preventScreenSaver 1

	logger "等待結束"
}

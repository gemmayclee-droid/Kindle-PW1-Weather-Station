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

	echo `date`: $MSG >> $LOGFILE
}

trace () {
	logger "追蹤 [$1] $2"
}

setup_debug_log () {
	if [ -z "$LOGFILE" ]; then
		return
	fi

	if [ -f "$LOGFILE" ] && [ "$(wc -c < "$LOGFILE")" -ge 262144 ]; then
		mv "$LOGFILE" "$LOGFILE.1"
	fi

	exec >> "$LOGFILE" 2>&1
	if [ "x$DEBUG" = "x1" ]; then
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
	lipc-set-prop -i com.lab126.powerd rtcWakeup $1 2>&1
	logger "已設定 rtcWakeup，喚醒倒數：$1 秒"
}

##############################################################################
# sets an RTC alarm
# arguments: $1 - time in seconds from now

wait_for () {
	ENDWAIT=$(( $(currentTime) + $1 ))
	REMAININGWAITTIME=$(( $ENDWAIT - $(currentTime) ))
	logger "開始等待下一次更新：$1 秒"

	# wait for timeout to expire
	while [ $REMAININGWAITTIME -gt 0 ]; do
		EVENT=$(lipc-wait-event -s $1 com.lab126.powerd readyToSuspend,wakeupFromSuspend,resuming)
		REMAININGWAITTIME=$(( $ENDWAIT - $(currentTime) ))
		logger "收到電源事件：$EVENT"

		case "$EVENT" in
			readyToSuspend*)
				set_rtc_wakeup $REMAININGWAITTIME
			;;
			wakeupFromSuspend*|resuming*)
				logger "裝置已喚醒，結束等待"
				break
			;;
			*)
				logger "忽略電源事件：$EVENT"
			;;
		esac
	done

	logger "等待結束"
}

#!/bin/sh

BOOT_LOG=/mnt/us/extensions/onlinescreensaver/onlinescreensaver.log
echo "$(date): 啟動前置記錄 $0" >> "$BOOT_LOG" 2>&1

# change to directory of this script
cd "$(dirname "$0")"

# load configuration
if [ -e "config.sh" ]; then
	. /mnt/us/extensions/onlinescreensaver/bin/config.sh
fi

# load utils
if [ -e "utils.sh" ]; then
	. /mnt/us/extensions/onlinescreensaver/bin/utils.sh
else
	echo "在 `pwd` 找不到 utils.sh"
	exit
fi

setup_debug_log

if [ -e /etc/upstart ]; then
	logger "正在啟用 Online Screensaver 自動更新"

	mntroot rw
	cp onlinescreensaver.conf /etc/upstart/
	mntroot ro

	start onlinescreensaver
else
	logger "找不到 Upstart 目錄，裝置韌體可能過舊"
fi

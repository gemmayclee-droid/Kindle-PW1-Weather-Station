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

# forever and ever, try to update the screensaver
logger "正在停用 Online Screensaver 自動更新"

stop onlinescreensaver || true      

mntroot rw
rm /etc/upstart/onlinescreensaver.conf
mntroot ro

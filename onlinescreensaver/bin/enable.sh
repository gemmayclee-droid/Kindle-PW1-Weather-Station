#!/bin/sh

BOOT_LOG=/mnt/us/extensions/onlinescreensaver/onlinescreensaver.log
echo "$(date): bootstrap $0" >> "$BOOT_LOG" 2>&1

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
	echo "Could not find utils.sh in `pwd`"
	exit
fi

setup_debug_log

if [ -e /etc/upstart ]; then
	logger "Enabling online screensaver auto-update"

	mntroot rw
	cp onlinescreensaver.conf /etc/upstart/
	mntroot ro

	start onlinescreensaver
else
	logger "Upstart folder not found, device too old"
fi

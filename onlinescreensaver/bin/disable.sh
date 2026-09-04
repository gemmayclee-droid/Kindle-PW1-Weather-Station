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

# forever and ever, try to update the screensaver
logger "Disabling online screensaver auto-update"

stop onlinescreensaver || true      

mntroot rw
rm /etc/upstart/onlinescreensaver.conf
mntroot ro

#!/bin/sh
#
##############################################################################
#
# Fetch weather screensaver from a configurable URL.

# change to directory of this script
cd "$(dirname "$0")"

# load configuration
if [ -e "config.sh" ]; then
	source /mnt/us/extensions/onlinescreensaver/bin/config.sh
else
	TMPFILE=/tmp/tmp.onlinescreensaver.png
fi

# load utils
if [ -e "utils.sh" ]; then
	source /mnt/us/extensions/onlinescreensaver/bin/utils.sh
else
	echo "Could not find utils.sh in `pwd`"
	exit
fi

# Local weatheriot mode: render weather.png on the Kindle, then use it as
# the linkss screensaver image. This avoids requiring an HTTP image server.
if [ -z "$IMAGE_URI" ]; then
	if [ -x "$LOCAL_WEATHER_SCRIPT" ] && [ -f "$LOCAL_WEATHER_IMAGE" -o -d "$(dirname "$LOCAL_WEATHER_IMAGE")" ]; then
		logger "IMAGE_URI is empty, running local weatheriot renderer"
		/bin/sh "$LOCAL_WEATHER_SCRIPT"
		LOCAL_RET=$?
		if [ "$LOCAL_RET" -eq 0 ] && [ -s "$LOCAL_WEATHER_IMAGE" ]; then
			cp "$LOCAL_WEATHER_IMAGE" "$TMPFILE" && mv "$TMPFILE" "$SCREENSAVERFILE"
			logger "Local weatheriot screensaver image updated"
			lipc-get-prop com.lab126.powerd status | grep "Screen Saver" && (
				logger "Updating image on screen"
				eips -f -g "$SCREENSAVERFILE"
			)
		else
			logger "Local weatheriot renderer failed (exit $LOCAL_RET)"
		fi
	else
		logger "No IMAGE_URI and local weatheriot renderer not found"
	fi
	exit 0
fi

# enable wireless if it is currently off
if [ 0 -eq `lipc-get-prop com.lab126.cmd wirelessEnable` ]; then
	logger "WiFi is off, turning it on now"
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
			logger "No internet connection after ${NETWORK_TIMEOUT} seconds, aborting."
			break
		else
			sleep 1
		fi
	fi
done

if [ 1 -eq $CONNECTED ]; then
	if wget -q $IMAGE_URI -O $TMPFILE; then
		mv $TMPFILE $SCREENSAVERFILE
		logger "Screen saver image updated"

		# refresh screen
		lipc-get-prop com.lab126.powerd status | grep "Screen Saver" && (
			logger "Updating image on screen"
			eips -f -g $SCREENSAVERFILE
		)
	else
		logger "Error updating screensaver"
		if [ 1 -eq $DONOTRETRY ]; then
			touch $SCREENSAVERFILE
		fi
	fi
fi

# disable wireless if necessary
if [ 1 -eq $DISABLE_WIFI ]; then
	logger "Disabling WiFi"
	lipc-set-prop com.lab126.cmd wirelessEnable 0
fi

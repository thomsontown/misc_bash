#!/bin/bash 


#    This script loads the Screen Sharing service and enables access for all users.

#    Author:      Andrew Thomson
#    Date:        03-01-2017
#    GitHub:      https://github.com/thomsontown


PRODUCT_VERSION=`/usr/bin/sw_vers -productVersion`
if [ ${PRODUCT_VERSION//./} -lt 10100 ]; then 
	echo "This script is not compatible with $PRODUCT_VERSION."
	exit 0
fi


if [ $EUID -ne 0 ]; then
	(>&2 echo "ERROR: Must run as root.")
	exit $LINENO
fi


if ! /bin/launchctl enable system/com.apple.screensharing; then 
	(>&2 echo "ERROR: Unable to enable Screen Sharing service.")
	exit $LINENO
fi


if ! /bin/launchctl load -w /System/Library/LaunchDaemons/com.apple.screensharing.plist 2> /dev/null; then
	(>&2 echo "ERROR: Unable to load Screen Sharing service.")
	exit $LINENO
fi


if /usr/bin/dscl . list /Groups/com.apple.access_screensharing &> /dev/null; then 
	if ! /usr/bin/dscl . change /Groups/com.apple.access_screensharing RecordName com.apple.access_screensharing com.apple.access_screensharing-disabled 2> /dev/null; then 
		(>&2 echo "ERROR: Unable to allow access for all users.")
		exit $LINENO
	fi
fi
#!/bin/sh

#    This script was written to enable ssh and provide login access to all users.

#    Author:        Andrew Thomson
#    Date:          03-10-2015
#    GitHub:        https://github.com/thomsontown


PRODUCT_VERSION=`/usr/bin/sw_vers -productVersion`
if [ ${PRODUCT_VERSION//./} -lt 10100 ]; then 
	echo "This script is not compatible with $PRODUCT_VERSION."
	exit 0
fi


if [ $EUID -ne 0 ]; then
	(>&2 echo "ERROR: Must run as root.")
	exit $LINENO
fi


if ! /usr/sbin/systemsetup -setremotelogin on &> /dev/null; then
	(>&2 echo "ERROR: Unabled to enable SSH.")
	exit $LINENO
fi


if /usr/bin/dscl . list /Groups/com.apple.access_ssh &> /dev/null; then 
	if ! /usr/bin/dscl . change /Groups/com.apple.access_ssh RecordName com.apple.access_ssh com.apple.access_ssh-disabled 2> /dev/null; then 
		(>&2 echo "ERROR: Unable to allow access for all users.")
		exit $LINENO
	fi
fi

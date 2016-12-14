#!/bin/bash


#	This script enumerates the items in each users' dock and removes any that reference missing apps or folders.
#	Both "persistent apps" and "other apps" are evaluated. Be sure to backup existing perference files before
#	running this script. Run at your own risk. 


#	Author: 	Andrew Thomson
#	Date : 		12-14-2016


DEBUG=true
PREFERENCES=(`/usr/bin/find /Users/*/Library/Preferences -iname "com.apple.dock.plist" -maxdepth 1 -type f -print`)


# 	make sure only root can run this script
if [[ $EUID -ne 0 ]]; then
   echo "ERROR: This script must be run as root."
   exit $LINENO
fi


#	display error if no preferences found
if [ -z ${#PRFERENCES[@]} ]; then
	echo "ERROR: No dock perferences found."
	exit $LINENO
fi


#	enumerate each dock preference file found
for PREFERENCE in ${PREFERENCES[@]} ; do

	#	get array of app paths
	PERSISTENT_APPS=(`/usr/libexec/PlistBuddy -c "print :persistent-apps" "${PREFERENCE}" | /usr/bin/awk '/CFURLString = /{print $3}'`)


	#	display debug info
	if $DEBUG; then echo "APPS COUNT: ${#PERSISTENT_APPS[@]}"; fi


	#	enumerate each app path
	for APP_PATH in ${PERSISTENT_APPS[@]}; do

		#	get index of current item 
		INDEX=`/usr/libexec/PlistBuddy -c "print :persistent-apps" "${PREFERENCE}" | /usr/bin/awk '/CFURLString = /{print $3}' | /usr/bin/nl | /usr/bin/grep -i "${APP_PATH}" | /usr/bin/awk '{print $1}' | /usr/bin/sort -rn`
		
		#	subtract 1 for zero-based arrays
		((INDEX = $INDEX - 1))

			#	display debug info
		if $DEBUG; then echo -e  "\n  CURRENT INDEX: $INDEX"; fi

		#	decode uri app path 
		APP_PATH=`/usr/bin/python -c 'import sys, urllib; print urllib.unquote(sys.argv[1])' "${APP_PATH#file://}"`

		#	display debug info
		if $DEBUG; then echo "  CURRENT PATH: $APP_PATH"; fi

		#	verify if app path exists
		if [ ! -e "${APP_PATH}" ]; then

			#	display item removal
			echo "REMOVING: $APP_PATH"

			#	remove missing app from dock if path does not exist 	
			/usr/libexec/PlistBuddy -c "delete :persistent-apps:'${INDEX}'" "${PREFERENCE}"
			/usr/libexec/PlistBuddy -c save "${PREFERENCE}" &> /dev/null
		fi
	done


	#	get array of folder paths
	PERSISTENT_OTHERS=(`/usr/libexec/PlistBuddy -c "print :persistent-others" "${PREFERENCE}" | /usr/bin/awk '/CFURLString = /{print $3}'`)


	#	display debug info
	if $DEBUG; then echo -e "\nOTHERS COUNT: ${#PERSISTENT_OTHERS[@]}"; fi


	#	enumerate each other path
	for OTHER_PATH in ${PERSISTENT_OTHERS[@]}; do
		
		#	get index of current item
		INDEX=`/usr/libexec/PlistBuddy -c "print :persistent-others" "${PREFERENCE}" | /usr/bin/awk '/CFURLString = /{print $3}' | /usr/bin/nl | /usr/bin/grep -i "${OTHER_PATH}" | /usr/bin/awk '{print $1}' | /usr/bin/sort -rn`
		
		#	subtract 1 for zero-based arrays
		((INDEX = $INDEX - 1))

		#	display debug info
		if $DEBUG; then echo -e  "\n  CURRENT INDEX: $INDEX"; fi

		#	decode uri other path
		OTHER_PATH=`/usr/bin/python -c 'import sys, urllib; print urllib.unquote(sys.argv[1])' "${OTHER_PATH#file://}"`

			#	display debug info
		if $DEBUG; then echo "  CURRENT PATH: $OTHER_PATH"; fi

		#	verify if other path missing	
		if [ ! -e "${OTHER_PATH}" ]; then

			#	display item removal
			echo "REMOVING: $OTHER_PATH"


			#	remove missing other from dock if path does not exist
			/usr/libexec/PlistBuddy -c "delete :persistent-others:'${INDEX}'" "${PREFERENCE}"
			/usr/libexec/PlistBuddy -c save "${PREFERENCE}" &> /dev/null
		fi
	done
done


#	restart dock
if ! /usr/bin/killall "Dock"; then
	echo "ERROR: Unable to restart Dock application."
	exit $LINENO
fi
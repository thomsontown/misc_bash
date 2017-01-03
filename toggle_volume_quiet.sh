#!/bin/bash


#	This script was written to quickly lower the volume within OS X but no to mute. 
#	Running the script a second time will restore the volume to the previous setting.
#	Each successive running of the script will toggle the volume appropriately. 


#	Author: 	Andrew Thomson
#	Date:		01/03/2017


#	get current output volume 
CURRENT_VOLUME=`/usr/bin/osascript -e "get output volume of (get volume settings)"`
if $DEBUG; then echo "CURRENT VOLUME: $CURRENT_VOLUME"; fi


#	exit if no output volume found
if [ -z $CURRENT_VOLUME ]; then
	echo "ERROR: Ubable to determine current volume."
	exit $LINENO
fi


#	adjust output volume
if [ $CURRENT_VOLUME -gt 1 ]; then

	#	save current output volume for later resotration
	echo CURRENT_VOLUME="$CURRENT_VOLUME" > "$HOME/.current_volume"

	#	set output volume to lowest setting
	if ! /usr/bin/osascript -e "set volume without output muted output volume 1"; then 
		echo "ERROR: Unable to set output volume."
		exit $LINENO
	fi
else

	#	load previously saved output volume if available
	if [ -f "$HOME/.current_volume" ]; then
		source "$HOME/.current_volume"
		if ! /usr/bin/osascript -e "set volume without output muted output volume $CURRENT_VOLUME"; then 
			echo "ERROR: Unable to set output volume."
			exit $LINENO
		fi
	else 

		#	no current output volume found, set volume to 35
		if ! /usr/bin/osascript -e "set volume without output muted output volume 35"; then 
			echo "ERROR: Unable to set output volume."
			exit $LINENO
		fi
	fi
fi
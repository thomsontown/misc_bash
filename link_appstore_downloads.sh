#!/bin/sh

#	Author: 	Andrew Thomson
#	Date: 		3/19/2014 

#    This script can be used to capture downloaded package files 
#    from the Mac App Store so the apps can be redistributed. The
#    package files will retain their Apple developer certificates 
#    but will NOT include the _MASReceipt from the App Store.

#    These redistributable packages are ideal for use with Casper 
#    but it does mean subsequent updates will similarly have to
#    be downloaded and distributed. Obviously this defeats the design 
#    of the App Store model, and should only be used with legally
#    purchased or free apps. Use at your own risk. 

#    Usage: Launch the script before clicking the "Install" button 
#    for a specific app in the Mac App Store. Once the selected app
#    package downloads, a copy (linked file) of the associated installer 
#    package will be renamed and moved to your desktop.


TEMP_PATH=`/usr/bin/mktemp -d /tmp/MAS_XXXX`
SEARCH_PATH="$(/usr/bin/getconf DARWIN_USER_CACHE_DIR)/com.apple.appstore"


#	set found to false to start
FOUND=false


#	loop thru looking for app store packages until one is found
until $FOUND; do
	
	#	get list of package files
	PACKAGELIST=$(/usr/bin/find $SEARCH_PATH -name "*.pkg" 2> /dev/null)

	#	link any found package files to desktop folder
	if [ ! -z "$PACKAGELIST" ]; then
		for PACKAGE in $PACKAGELIST; do
			/bin/ln $PACKAGE ${TEMP_PATH}/${PACKAGE##*/}
		done

		#	end loop
		FOUND=true		
	fi
done


#   loop thru until no app store packages are found, then rename
while $FOUND; do
    for PACKAGE in $PACKAGELIST; do
        if [ ! -e "${PACKAGE}" ]; then

        	#	get internal package name
            TITLE=`/usr/sbin/installer -verbose -pkginfo -pkg "${TEMP_PATH}/${PACKAGE##*/}" | /usr/bin/awk -F": " '/Title/ {print $2; exit}'`

            #	rename and move package to desktop
            /bin/mv "${TEMP_PATH}/${PACKAGE##*/}" "$HOME/Desktop/$TITLE.pkg"

            #	end loop
            FOUND=false
        fi
    done
done


#	remove temp folder and its contents
if [ -d "${TEMP_PATH}" ]; then /bin/rm -rf "${TEMP_PATH}"; fi


#	singnal completion
if [ -f /System/Library/Sounds/Glass.aiff ]; then /usr/bin/afplay /System/Library/Sounds/Glass.aiff; fi
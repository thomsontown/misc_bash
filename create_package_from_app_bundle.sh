#!/bin/sh

#	This script was written to quickly and easily create "component" package 
#	files for simple application bundles that are typically downloaded within
#	a disk image file or in a compressed file format. The script must run as 
#	root. You can include the path to the application bundle as a parameter 
#	when running the sciprt, or when prompted, enter it manually or drag and 
#	drop into the terminal window and press the ENTER key. 

#	I've added variables for PREFIX and SUFFIX so as to be able to customize 
#	the name of the newly generated package file.

#	The resulting package files are NOT package archives suitable for uploading
#	to Apple for use in the Mac App Store. They are, however, ideal for use 
#	within JAMF PRO. 

#	Author: 	Andrew Thomson
#	Date:		11-07-2014
	

SOURCE=${1%/}                       #	application bundle path as command line argument
DESTINATION="/Applications"         #	install destination of application
PREFIX="SW - "                      #	prefix of package file name
SUFFIX=" v"                         #	suffix of package file name before version number
PKGPATH="$HOME/Desktop/"            #	location where package file will be saved


function onExit() {
	ERROR_CODE=$?
	if [ -d "$TMP_SOURCE" ]; then /bin/rm -rf "$TMP_SOURCE"; fi
	if [ -f "$TMP_PLIST" ]; then /bin/rm "$TMP_PLIST"; fi
	echo  "Exited with code #${ERROR_CODE} after $SECONDS second(s)."
}


#	make sure to cleanup on exit
trap onExit EXIT


# 	make sure only root can run our script
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 1>&2
   exit $LINENO
fi


#	copy script to destination -- optional
if [ ! -x /usr/local/bin/quickpkg ]; then /bin/cp "$0" /usr/local/bin/quickpkg; fi


#	get the path to the source app to package
if [ -z "$SOURCE" ]; then
	echo "Please enter the path to the application you want to package, or drag and drop it into this window. Then press the enter key."
	read SOURCE
	if [ ! -d "$SOURCE" ]; then 
		echo "ERROR: The application cannot be found."
		exit $LINENO
	fi
fi


#	remove any trailing slashes from source path
SOURCE="${SOURCE%/}"


#	if the source path contains /Applications, update the destination
if [[ ${SOURCE} == *"/Applications"* ]]; then 
	if ! DESTINATION=`/usr/bin/dirname "${SOURCE}"`; then
		echo "ERROR: Unable to set the target destination."
		exit $LINENO
	fi
fi


#	read info.plist to get source attributes
if [ -f "${SOURCE}/Contents/Info.plist" ]; then
	
	#	get app bundle name 
	if ! NAME=`/usr/bin/defaults read "${SOURCE}/Contents/Info" CFBundleName 2> /dev/null`; then 
		
		#	as alternate
		NAME=`/usr/bin/basename -a .app "$SOURCE"`
	fi	
	
	#	get app bundle version
	if ! VERSION=`/usr/bin/defaults read "${SOURCE}/Contents/Info" CFBundleShortVersionString 2> /dev/null`; then

		#	as alternate
		VERSION=`/usr/bin/defaults read "${SOURCE}/Contents/Info" CFBundleVersionString 2> /dev/null`
	fi
	
	#	get app bundle identifier
	IDENTIFIER=`/usr/bin/defaults read "${SOURCE}/Contents/Info" CFBundleIdentifier 2> /dev/null` 
fi


#	make sure all variables have values
if [[ -z ${NAME} ]] || [[ -z ${VERSION} ]] || [[ -z ${IDENTIFIER} ]]; then
	echo "ERROR: One or more attributes could not be found."
	exit $LINENO
fi


#	find developer certificate
if /usr/bin/security find-certificate -c "Developer ID Installer" &> /dev/null; then
	echo "Developer certificate found."
	
	#	parse certificate id
	DEVELOPER_ID=`/usr/bin/security find-certificate -c "Developer ID Installer" | grep "labl" | /usr/bin/awk -F"\"" '{print $4}'`
	echo "Digital Certificate: $DEVELOPER_ID"
fi


#	make temp folder
TMP_SOURCE=`/usr/bin/mktemp -d "/tmp/$NAME.XXXX"`
TMP_SOURCE="$TMP_SOURCE/"
TMP_PLIST=`/usr/bin/mktemp "/tmp/$NAME.XXXX"`


#	copy source to temp location
echo "Copying source to temp location . . ."
if ! /bin/cp -R "$SOURCE" "$TMP_SOURCE/" 2> /dev/null; then
	echo "ERROR: Unable to copy source to temp location."
	exit $LINENO
fi


#	display variables
echo Application Name:  $NAME
echo Application Version:  $VERSION
echo Application Identifier:  $IDENTIFIER
echo Application Source:  \"$TMP_SOURCE\"
echo Application Destination:  \"$DESTINATION\"


#	set permissions
if ! /bin/chmod -R 755 "$TMP_SOURCE" 2> /dev/null; then
	echo "ERROR: Unable to set permissions."
	exit $LINENO
fi


#	remove any extended attributes
if ! /usr/bin/xattr -rc "$TMP_SOURCE" 2> /dev/null; then 
	echo "ERROR: Unable to remove extended attributes."
	exit $LINENO
fi


#	generate component property file
if ! /usr/bin/pkgbuild --analyze --root "$TMP_SOURCE" "$TMP_PLIST"; then
	echo "ERROR: Unable to analyze source."
	exit $LINENO
fi


#	build package file
if [[ -z $DEVELOPER_ID ]]; then
	echo "Building package without digital signature . . ."
	if ! /usr/bin/pkgbuild --root "${TMP_SOURCE}" --install-location "${DESTINATION}" --component-plist "${TMP_PLIST}" --identifier "${IDENTIFIER}" --version "${VERSION}" "${PKGPATH}${PREFIX}${NAME}${SUFFIX}${VERSION}.pkg" 2> /dev/null; then
		echo "An error occurred while building the package."
		exit $LINENO
	fi
else
	echo "Building package with digital signature . . ."
	if ! /usr/bin/pkgbuild --root "${TMP_SOURCE}" --install-location "${DESTINATION}" --sign "$DEVELOPER_ID" --component-plist "${TMP_PLIST}" --identifier "${IDENTIFIER}" --version "${VERSION}" "${PKGPATH}${PREFIX}${NAME}${SUFFIX}${VERSION}.pkg" 2> /dev/null; then
		echo "An error occurred while building the package."
		exit $LINENO
	fi
fi

#!/bin/bash


#    This script was written to run from a launch daemon to monitor
#    password expirations for elevated domain accounts. Domain accounts
#    with any of the following prefixes (DA-, EP-, WA-) and also listed 
#    in the local admin group are monitored for approaching password
#    expirations. Accounts due to expire within 5 days are displayed
#    to the user with the option to change the passwords.

#    This script was born out of a need whereby elevated mobile domain 
#    credentials are required by users logged in with standard 
#    accounts to make specific changes or to respond to elevated 
#    credential prompts for package installs. 

#    Since these elevated accounts are not intended to be directly 
#    logged into, there is no obvious indication that their passwords
#    are due to expire. This script not only provides notification, but 
#    also a step-by-step method for changing the elevated account passwords.

#    Author:    Andrew Thomson
#    Date:      2017-09-25
#    GitHub:    https://github.com/thomsontown


function installPwdmonitor() {
	
	#	install script to local bin with short name 
	if [ ! -x /usr/local/bin/pwdmonitor ]; then /usr/bin/install -o 0 -g 0 "$0" /usr/local/bin/pwdmonitor; fi

	#	write xml to launch daemon
	echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?> 
		<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\"> 
		<plist version=\"1.0\"> 
		<dict>
			<key>Label</key>
			<string>com.thomsontown.pwdmonitor</string>
			<key>ProgramArguments</key>
			<array>
				<string>/usr/local/bin/pwdmonitor</string>
			</array>
			<key>RunAtLoad</key>
			<true/>
			<key>StartCalendarInterval</key>
			<dict>
				<key>Hour</key>
				<integer>12</integer>
				<key>Minute</key>
				<integer>0</integer>
			</dict>
		</dict>
		</plist>" | /usr/bin/xmllint --format - > /Library/LaunchDaemons/com.thomsontown.pwdmonitor.plist

	#	set permissions and launch daemon
	/usr/sbin/chown root:wheel /Library/LaunchDaemons/com.thomsontown.pwdmonitor.plist
	/bin/chmod 644 /Library/LaunchDaemons/com.thomsontown.pwdmonitor.plist
	/bin/launchctl load -w /Library/LaunchDaemons/com.thomsontown.pwdmonitor.plist
}



function getPassword() {
	/usr/bin/osascript -e  "text returned of (display dialog \"$1\" default answer \"\" with hidden answer with title \"Password Change\" buttons {\"Ok\"} default button \"Ok\")"
}


function displayDialog() {
	/usr/bin/osascript -e  "display dialog \"$1\" with title \"Password Change\" buttons {\"Ok\"} default button \"Ok\")"
}


function changePassword() {
	OLD_PWD=`getPassword "Old Password ($ADMIN:)"`
	NEW_PWD=`getPassword "New Password ($ADMIN:)"`
	VER_PWD=`getPassword "Verify Password ($ADMIN:)"`

	#	error if no password entered
	if [[ -z $OLD_PWD ]] || [[ -z $NEW_PWD ]] || [[ -z $VER_PWD ]]; then 
		displayDialog "ERROR: One or more passwords not entered." 
		exit $LINENO
	fi

	#	error if passwords don't match
	if [[ "$NEW_PWD" != "$VER_PWD" ]]; then 
		displayDialog "ERROR: New passwords do not match."
		exit $LINENO
	fi

	#	error if old password is incorrect
	if ! /usr/bin/dscl . -authonly $ADMIN "$OLD_PWD"; then 
		displayDialog "ERROR: Old password is invalid."
		exit $LINENO
	fi

	#	attempt to change password
	if RETURN_CODE=`/usr/bin/dscl . -passwd /Users/$ADMIN "$OLD_PWD" "$NEW_PWD"`; then
		displayDialog "Password successfully updated: ($ADMIN)."

	elif echo "$RETURN_CODE" | /usr/bin/grep "eDSServiceUnavailable" ; then
		displayDialog "ERROR: Unable to updated password: ($ADMIN). Active Directory not available."
		exit $LINENO

	elif echo "$RETURN_CODE" | /usr/bin/grep "eDSAuthMethodNotSupported" ; then
		displayDialog "ERROR: Unable to updated password: ($ADMIN). Password does not meeting required complexity."
		exit $LINENO

	else
		displayDialog "ERROR: Unable to updated password: ($ADMIN)."
		exit $LINENO
	fi
}


#	check for install
if [ $EUID -eq 0 ] && ([ ! -x /usr/local/bin/pwdmonitor ] || [ ! -f /Library/LaunchDaemons/com.thomsontown.pwdmonitor.plist ] || ! /bin/launchctl list | /usr/bin/grep "com.thomsontown.pwdmonitor" &> /dev/null); then
	if $DEBUG; then echo "Installing pwdmonitor . . ."; fi
	installPwdmonitor
fi


#	get domain user admins
ADMINS=(`/usr/bin/dscl /Local/Default -list /Users UniqueID | /usr/bin/awk '$2 >= 1000000 { print $1 }'`)


#	enumerate admin accounts
for ADMIN in ${ADMINS[@]}; do 

	#	if admin matches elevated privilege format 
	if echo ADMIN | /usr/bin/tr [:lower:] [:upper:] | /usr/bin/grep -E "^[ADEPW]{2}\-.*?"; then 

		#	get original node location 
		NODE_NAME=`/usr/bin/dscl . read /Users/$ADMIN OriginalNodeName | /usr/bin/awk '/^OriginalNodeName:/ {getline; print}'`

		#	get epoch date password set to expire
		EPOCH_MAXAGE=`/usr/bin/dscl "${NODE_NAME#?}" read /Users/$ADMIN msDS-UserPasswordExpiryTimeComputed | /usr/bin/awk '/dsAttrTypeNative:msDS-UserPasswordExpiryTimeComputed:/ {printf "%.0f", $2/10000000-11644473600}'`
		
		#	get epoch date password was last set
		EPOCH_PWDSET=`/usr/bin/dscl "${NODE_NAME#?}" read /Users/$ADMIN pwdLastSet | /usr/bin/awk '/pwdLastSet:/ {printf "%.0f", $2/10000000-11644473600}'`
		
		#	get epoch of todays date
		EPOCH_TODAY=`/bin/date "+%s"`

		#	calculate how many days before password expires
		DAYS_PWDEXP=`/bin/expr \( $EPOCH_MAXAGE - $EPOCH_TODAY \) / 86400` 

		#	convert epoch date password set to expire into standard date and time format
		DATE_PWDEXP=`/bin/date -j -f %s $EPOCH_MAXAGE`

		#	echo for debug
		if $DEBUG; then
			echo "ID:      $ADMIN"
			echo "DAYS:    $DAYS_PWDEXP"
			echo "DATE:    $DATE_PWDEXP"
		fi

		#	check if expiration date soon
		if [ $DAYS_PWDEXP -le 5 ]; then

			#	prompt to change password
			BUTTON_RETURNED=`/usr/bin/osascript -e "button returned of (display dialog \"Password for $ADMIN will expire on $DATE_PWDEXP. Would you like to change it now?\" with title \"Password Expiration\" buttons {\"Yes\", \"No\"} default button \"Yes\")"`
			
			#	change password on yes button
			if [ $BUTTON_RETURNED == Yes ]; then changePassword; fi
		fi	
	fi
done

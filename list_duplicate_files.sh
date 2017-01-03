#!/bin/bash


#	This script searches for duplicate files based on checksum. Duplicates are displayed with their
#	checksum CRC followed by file paths. The output can be piped to a file for subseqent analysis.
#	Include a path as a parameter to search, otherwise the current folder will be searched by default.


#	Author:		Andrew Thomson
#	Date:		12-31-2016


#	set internal field separator to new line character
IFS=$'\n'


#	create array of all files and their complete cksum information including path
echo "Searching for files . . ."
ARRAY_ALL_FILES=(`/usr/bin/find "${1:-.}" \! -type d -exec /usr/bin/cksum {} \; 2> /dev/null`)
if $DEBUG; then echo "TOTAL FILES: ${#ARRAY_ALL_FILES[@]}"; fi


#	create array of just cksums 	
for INDEX in ${!ARRAY_ALL_FILES[@]}; do
	ARRAY_ALL_CKSUM+=(`echo ${ARRAY_ALL_FILES[$INDEX]} | /usr/bin/awk '{print $1}'`)
done	


#	create array of only duplicate cksums
ARRAY_DUPLICATE_CHKSUM+=(`echo ${ARRAY_ALL_CKSUM[@]} | /usr/bin/awk 'BEGIN{RS=" ";} {print $1}' | /usr/bin/uniq -d`)
if $DEBUG; then echo "DUPLICATE FILES: ${#ARRAY_DUPLICATE_CHKSUM[@]}"; fi


#	enumerate duplicate cksums to match up with path info
if  [ ${#ARRAY_DUPLICATE_CHKSUM[@]} -ne 0 ]; then 
	echo "Finding duplicates . . ."
	for DUPLICATE in ${ARRAY_DUPLICATE_CHKSUM[@]}; do
		for INDEX in  ${!ARRAY_ALL_FILES[@]} ; do
			if echo ${ARRAY_ALL_FILES[$INDEX]} | /usr/bin/grep $DUPLICATE &> /dev/null; then 
				echo ${ARRAY_ALL_FILES[$INDEX]} | /usr/bin/awk '{out=""; for(i=3;i<=NF;i++){out=out" "$i}; print $1, out}'
			fi
		done
	done
else 
	echo "No duplicates found."
fi


#	play audio complete sound
/usr/bin/afplay /System/Library/Sounds/Glass.aiff
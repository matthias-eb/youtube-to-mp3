#!/bin/bash

RED='\033[0;31m'
NC='\033[0m' # No Color
changes_made=false

git checkout master

if [ -f "youtube-to-mp3_i386.deb" ]; then
	rm "youtube-to-mp3_i386.deb"
fi
if [ -f "youtube-to-mp3_x86_64.deb" ]; then
	rm "youtube-to-mp3_x86_64.deb"
fi

wget -O "youtube-to-mp3_i386.deb" "https://www.mediahuman.com/de/download/YouTubeToMP3.i386.deb" # Download 32 Bit File
wget -O "youtube-to-mp3_x86_64.deb" "https://www.mediahuman.com/de/download/YouTubeToMP3.amd64.deb" # Download 64 Bit File

if [ ! -f md5sum_i386 ]; then
	md5sum "youtube-to-mp3_i386.deb" > md5sum_i386
fi
if [ ! -f md5sum_x86_64 ]; then
	md5sum "youtube-to-mp3_x86_64.deb" > md5sum_x86_64
fi

md5sum -c md5sum_i386 --status
if [ $? -eq 0 ]; then
	echo "File 'youtube-to-mp3_i386.deb' OK."
else
	echo -e "${RED}File 'youtube-to-mp3_i386.deb' changed! Updating md5sum..${NC}"
	if [ -f md5sum_i386 ]; then
		rm md5sum_i386
	fi
	md5sum "youtube-to-mp3_i386.deb" > md5sum_i386
	md5_i386=$(cat md5sum_i386 | cut -d ' ' -f 1)	# Take the md5um String, cut it at the space, take the first part and save it to md5_x68_64.
	sed -i "s/md5sums_i386=(.\+/md5sums_i386=(\"${md5_i386}\")/" PKGBUILD # Replace the first line in PKGBUILD starting with md5sums_i386=( with the same string and the added new md5sum
	git add PKGBUILD
	changes_made=true
fi
md5sum -c md5sum_x86_64 --status
if [ $? -eq 0 ]; then
	echo "File 'youtube-to-mp3_x86_64.deb' OK."
else
	echo -e "${RED}File 'youtube-to-mp3_x86_64.deb' changed! Updating md5sum..${NC}"
	if [ -f md5sum_x86_64 ]; then
		rm md5sum_x86_64
	fi
	md5sum "youtube-to-mp3_x86_64.deb" > md5sum_x86_64
	md5_x86_64=$(cat md5sum_x86_64 | cut -d ' ' -f 1)	# Take the md5um String, cut it at the space, take the first part and save it to md5_x68_64.
	sed -i "s/md5sums_x86_64=(.\+/md5sums_x86_64=(\"$md5_x86_64\")/" PKGBUILD # Replace the first line starting with md5sums_x86_64=( with the same string and the added new md5sum
	git add PKGBUILD
	changes_made=true
fi

if [ $changes_made = true ]; then
	# Update .SRCINFO
	makepkg -cf
	makepkg --printsrcinfo > .SRCINFO
	git add .SRCINFO

	# Update repository
	git commit -m "Updated md5sums and .SRCINFO"
	echo "Updated md5sums and .SRCINFO. Waiting 10 seconds before pushing.."
	sleep 10
	git push origin aur
fi

## Cleanup
rm "youtube-to-mp3_i386.deb"
rm "youtube-to-mp3_x86_64.deb"
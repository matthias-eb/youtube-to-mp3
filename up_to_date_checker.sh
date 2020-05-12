#!/bin/bash

RED='\033[0;31m'
NC='\033[0m' # No Color
changes_made=false



if [ -f "youtube-to-mp3_i386.deb" ]; then
	rm "youtube-to-mp3_i386.deb"
fi
if [ -f "youtube-to-mp3_x86_64.deb" ]; then
	rm "youtube-to-mp3_x86_64.deb"
fi

wget -O "youtube-to-mp3_i386.deb" "https://www.mediahuman.com/de/download/YouTubeToMP3.i386.deb" # Download 32 Bit File
wget -O "youtube-to-mp3_x86_64.deb" "https://www.mediahuman.com/de/download/YouTubeToMP3.amd64.deb" # Download 64 Bit File

# If the script is run for the first time, just create the files and upload them
if [ ! -f md5sum_i386 ]; then
	echo "md5sum Datei i386 neu erstellt."
	md5sum "youtube-to-mp3_i386.deb" > md5sum_i386
	changes_made=true
fi
if [ ! -f md5sum_x86_64 ]; then
	echo "md5sum Datei x86_64 neu erstellt."
	md5sum "youtube-to-mp3_x86_64.deb" > md5sum_x86_64
	changes_made=true
fi
if [ $changes_made == "true" ]; then
	echo "Updating checksums and terminating.."
	git add md5sum_x86_64 md5sum_i386
	git commit -m "Changed md5sums."
	git push
	changes_made=false
fi

# Check for changes in the md5sum
md5sum -c md5sum_i386 --status
if [ $? -eq 0 ]; then
	echo "File 'youtube-to-mp3_i386.deb' OK."
else
	echo -e "${RED}File 'youtube-to-mp3_i386.deb' changed! Updating md5sum..${NC}"
	md5_i386=$(md5sum "youtube-to-mp3_i386.deb" | cut -d ' ' -f 1)
	sed -i "s/md5sums_i386=(.\+/md5sums_i386=(\"${md5_i386}\")/" PKGBUILD # Replace the first line in PKGBUILD starting with md5sums_i386=( with the same string and the added new md5sum
	git add PKGBUILD
	changes_made=true
fi
md5sum -c md5sum_x86_64 --status
if [ $? -eq 0 ]; then
	echo "File 'youtube-to-mp3_x86_64.deb' OK."
else
	echo -e "${RED}File 'youtube-to-mp3_x86_64.deb' changed! Updating md5sum..${NC}"
	md5_x86_64=$(md5sum "youtube-to-mp3_x86_64.deb" | cut -d ' ' -f 1)
	sed -i "s/md5sums_x86_64=(.\+/md5sums_x86_64=(\"$md5_x86_64\")/" PKGBUILD # Replace the first line starting with md5sums_x86_64=( with the same string and the added new md5sum
	git add PKGBUILD
	changes_made=true
fi

git checkout master

if [ $changes_made == "true" ]; then
	# Update .SRCINFO
	makepkg -cf
	if [ $? -ne 0 ]; then
		echo "Building the package failed. Please check above. Terminating..."
		exit -2
	fi
	makepkg --printsrcinfo > .SRCINFO
	git add PKGBUILD .SRCINFO

	# Update repository
	git commit -m "PKGBUILD md5sums and .SRCINFO"
	echo "Updated PKGBUILD md5sums and .SRCINFO. Waiting 10 seconds before pushing. To cancel, press Ctrl+C"
	git status
	sleep 10
	git push origin master
	echo "Do you want to publish the updated PKGBUILD and .SRCINFO to the AUR?"
	read answer
	if [ $answer == "yes" ]; then
		git push origin aur
	fi
	echo "Pushing the updated checksums to the home repository"
	git checkout update_script
	md5sum "youtube-to-mp3_x86_64.deb" > md5sum_x86_64
	md5sum "youtube-to-mp3_i386.deb" > md5sum_i386
	git add md5sum_x86_64 md5sum_i386
	git commit -m "Changed md5sums."
	git push
fi

## Cleanup
rm "youtube-to-mp3_i386.deb"
rm "youtube-to-mp3_x86_64.deb"
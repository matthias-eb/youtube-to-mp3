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
	echo "Adding checksums for the first time"
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
	git checkout master
	sed -i "s/md5sums_i386=(.\+/md5sums_i386=(\"${md5_i386}\")/" PKGBUILD # Replace the first line in PKGBUILD starting with md5sums_i386=( with the same string and the added new md5sum
	git add PKGBUILD
	git commit -m "32 Bit md5sum changed for PKGBUILD"
	changes_made=true
	git checkout update_script
fi
md5sum -c md5sum_x86_64 --status
if [ $? -eq 0 ]; then
	echo "File 'youtube-to-mp3_x86_64.deb' OK."
else
	echo -e "${RED}File 'youtube-to-mp3_x86_64.deb' changed! Updating md5sum..${NC}"
	md5_x86_64=$(md5sum "youtube-to-mp3_x86_64.deb" | cut -d ' ' -f 1)
	git checkout master
	sed -i "s/md5sums_x86_64=(.\+/md5sums_x86_64=(\"$md5_x86_64\")/" PKGBUILD # Replace the first line starting with md5sums_x86_64=( with the same string and the added new md5sum
	git add PKGBUILD
	git commit -m "64 Bit md5sum changed for PKGBUILD"
	changes_made=true
fi

if [ $changes_made == "true" ]; then
	# Update .SRCINFO
	pkgverline="$(cat PKGBUILD | grep pkgver= | head -1)"
	pkgrelline=$(cat PKGBUILD | grep 'pkgrel')
	pkgrel=${pkgrelline#*=}
	makepkg -cf
	if [ $? -ne 0 ]; then
		echo "Building the package failed. Please check above. Terminating..."
		exit -2
	fi
	if [ $pkgverline == $(cat PKGBUILD | grep pkgver= | head -1) ]; then
		let "pkgrel++"
		pkgrelline="${pkgrelline%=*}=$pkgrel"
		echo "${RED}$pkgrelline${NC}"
		sed -i "s/pkgrel=.\+/$pkgrelline/" PKGBUILD

		# Rebuild Package
		makepkg -cf
		if [ $? -ne 0 ]; then
			echo "Building the package failed. Please check above. Terminating..."
			exit -2
		fi
	elif (( pkgrel >= 2 )); then
		pkgrel = 1
		pkgrelline="${pkgrelline%=*}=$pkgrel"
		echo "${RED}$pkgrelline${NC}"
		sed -i "s/pkgrel=.\+/$pkgrelline/" PKGBUILD

		# Rebuild Package
		makepkg -cf
		if [ $? -ne 0 ]; then
			echo "Building the package failed. Please check above. Terminating..."
			exit -2
		fi
	fi
	makepkg --printsrcinfo > .SRCINFO
	git add PKGBUILD .SRCINFO
	git commit -m ".SRCINFO regenerated, updated Package Version to ${pkgverline#*=} and Package Release Nr. to $pkgrel"

	# Update repository
	git status
	echo "Do you want to publish the updated PKGBUILD and .SRCINFO to the AUR?"
	answer=""
	while [ "$answer" != "n" ] && [ "$answer" != "y" ] && [ "$answer" != "yes" ] && [ "$answer" != "no" ]; do
		read answer
		answer="${answer,,}"
		if [ "$answer" = "yes" ] || [ "$answer" = "y" ]; then
			git push aur
			if [ $? -ne 0 ]; then
				echo "Pushing failed. Please check for errors."
			fi
		elif [ "$answer" = "no" ] || [ "$answer" = "n" ]; then
			echo "Skipping AUR push.."
		else
			echo "Please Write one of the following and press enter: yes/no/y/n"
		fi
	done
	echo "Pushing PKGBUILD and .SRCINFO to home repository.."
	git push origin master
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
rm "*.pkg.tar.xz"
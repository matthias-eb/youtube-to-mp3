#!/bin/bash
## This script is for keeping the AUR package youtube-to-mp3 up to date with the md5sums.
## It automates the packaging, pushing and is keeping the files koherent. It updates the Checksums once per date.
##
## Exit states:
##	0: Everything went according to plan.
##	-1: Downloading the sources failed. This can happen due to no internet connection or a timeout.
##	-2: Packaging failed. Possibly the md5sum was not correct or another error occured.
##	-3: Pushing to remote Branch failed. Possibly faulty Files in the branch or a connection issue?
##
## The md5 checksum Files are located in the update_script branch.
## PKGBUILD and .SRCINFO are located in the master branch. This Branch is pushed to the aur and origin remote master branches.

MSG_32_SUM_CHANGED="32 Bit md5sum changed for PKGBUILD"
MSG_32_DATE_CHANGED="Date of the 32 Bit md5sum file changed"
MSG_64_SUM_CHANGED="64 Bit md5sum changed for PKGBUILD"
MSG_64_DATE_CHANGED="Date of the 64 Bit md5sum file changed"
MSG_DATE_ADDED="Date added for checksum File"

RED='\033[0;31m'
NC='\033[0m' # No Color
changes_made=false
skip=false
md5_changes=false

function revertCommits() {
	## Revert committed changes
	last_commit=$(git log -1 --format=format:%s)
	commit_date=$(git log -1 --date=short --format=format:%cd)
	# Remove tha last commit as long as it has the current date and 
	while [ \( "$last_commit" = "$MSG_32_SUM_CHANGED" -o "$last_commit" = "$MSG_64_SUM_CHANGED" -o "$last_commit" = "$MSG_DATE_ADDED" \) -a \( "$commit_date" = "$(date --rfc-3339=date)" \) ]; do
		if [ "$last_commit" = "$MSG_DATE_ADDED" ]; then
			# To be tested. For now, just abort.
			# git reset --keep HEAD~1
			echo -e "${RED}Date commit recognized. Stopping for now. Please remove any commits that you don't want by hand.${NC}"
			break
		else
			echo -e "${RED}Removing following commit:${NC}" 
			git log -1
			git reset --hard HEAD~1
		fi
		last_commit=$(git log -1 --format=format:%s)
		commit_date=$(git log -1 --date=short --format=format:%cd)
	done
}

function removeFiles() {
	## Try to delete those Files while ignoring the output
	rm youtube-to-mp3_i386.deb > /dev/null 2>&1
	rm youtube-to-mp3_x86_64.deb > /dev/null 2>&1
	rm *.pkg.tar.xz > /dev/null 2>&1
	rm *.pkg.tar.zst > /dev/null 2>&1
	rm *.part > /dev/null 2>&1
}

function getSources_i386() {
	# Download i386 source
	wget --no-check-certificate -O "youtube-to-mp3_i386.deb" "https://www.mediahuman.com/de/download/YouTubeToMP3.i386.deb" # Download 32 Bit File
	if [ $? -ne 0 ]; then
		echo -e "${RED}Downloading .deb File failed. Please check the error above. Maybe an internet connection is not established?${NC}"
		removeFiles
		exit -1
	fi
}

function getSources_x86_64() {
	# Download sources for x86_64 Architecture
	wget --no-check-certificate -O "youtube-to-mp3_x86_64.deb" "https://www.mediahuman.com/de/download/YouTubeToMP3.amd64.deb" # Download 64 Bit File
	if [ $? -ne 0 ]; then
		echo -e "${RED}Downloading .deb File failed. Please check the error above. Maybe an internet connection is not established?${NC}"
		removeFiles
		exit -1
	fi
}

function update_md5_i386() {
	# Check if the md5sum still matches
	md5sum -c md5sum_i386 --status
	if [ $? -eq 0 ]; then
		# The checksum matches
		# Change to the correct branch if necessary
		if [ "$(git branch --show-current)" != "update_script" ]; then
			git checkout update_script
		fi
		# Check, if the date still matches
		if [ "$(date --rafc-3339=date)" != "$(sed '2q;d' md5sum_i386)" ]; then
			echo "Changing date for 32 Bit md5sum file"
			# If the date does'nt match, replace the second line in the file with the new md5sum
			sed -i "2s/.*/$(date --rfc-3339=date)/" md5sum_i386
			git add md5sum_i386
			git commit -m "$MSG_32_DATE_CHANGED"
			md5_changes=true
		else
			echo "File 'youtube-to-mp3_i386.deb' OK."
		fi
	else
		# The md5sum changed. We need to replace it in both the PKGBUILD and the md5sum file.
		# Change to the correct branch if necessary
		if [ "$(git branch --show-current)" != "master" ]; then
			git checkout master
		fi
		echo -e "${RED}Md5sum for Architecture i386 changed! Updating.${NC}"
		# Get the md5sum from the deb File
		md5_i386=$(md5sum "youtube-to-mp3_i386.deb" | cut -d ' ' -f 1)
		# Replace the first line in PKGBUILD starting with md5sums_i386=( with the same string and the added new md5sum as well as a ")"
		sed -i "s/md5sums_i386=(.\+/md5sums_i386=(\"${md5_i386}\")/" PKGBUILD
		# Set the flag to push the master branch of the aur and origin 
		changes_made=true
		git add PKGBUILD
		git commit -m "$MSG_32_SUM_CHANGED"

		# Now, rewrite the md5sum file and commit to the update_script branch as well 
		git checkout update_script
		md5sum "youtube-to-mp3_i386.deb" > md5sum_i386
		date --rfc-3339=date >> md5sum_i386
		git add md5sum_i386
		git commit -m "$MSG_32_SUM_CHANGED"
		# Set the flag to push to the update_script branch
		md5_changes=true
	fi
}

function update_md5_x86_64() {
	md5sum -c md5sum_x86_64 --status
	if [ $? -eq 0 ]; then
		# The checksum matches
		# Change to the correct branch if necessary
		if [ "$(git branch --show-current)" != "update_script" ]; then
			git checkout update_script
		fi
		# Check, if the date still matches
		if [ "$(date --rfc-3339=date)" != "$(sed '2q;d' md5sum_x86_64)" ]; then
			echo "Changing date for 64 Bit md5sum file"
			sed -i "2s/.*/$(date --rfc-3339=date)/" md5sum_x86_64
			git add md5sum_x86_64
			git commit -m "$MSG_64_DATE_CHANGED"
			md5_changes=true
		else
			echo "File 'youtube-to-mp3_x86_64.deb' OK."
		fi
	else
		# The md5sum changed. We need to replace it in both the PKGBUILD and the md5sum file.
		# Change to the correct branch if necessary
		if [ "$(git branch --show-current)" != "master" ]; then
			git checkout master
		fi
		echo -e "${RED}Md5sum for Architecture x86_64 changed! Updating.${NC}"
		# Get the md5sum from the deb File
		md5_x86_64=$(md5sum "youtube-to-mp3_x86_64.deb" | cut -d ' ' -f 1)
		# Replace the first line in PKGBUILD starting with 'md5sums_x86_64=(' with that same string and the added new md5sum as well as a ')'"
		sed -i "s/md5sums_x86_64=(.\+/md5sums_x86_64=(\"${md5_x86_64}\")/" PKGBUILD
		# Set the flag to push the master branch of the aur and origin
		changes_made=true
		git add PKGBUILD
		git commit -m "$MSG_64_SUM_CHANGED"

		# Now, rewrite the md5sum file and commit to the update_script branch as well 
		git checkout update_script
		md5sum "youtube-to-mp3_x86_64.deb" > md5sum_x86_64
		date --rfc-3339=date >> md5sum_x86_64
		git add md5sum_x86_64
		git commit -m "$MSG_64_SUM_CHANGED"
		# Set the flag to push to the update_script branch
		md5_changes=true
	fi
}

function buildPackage() {
	makepkg -cf
	if [ $? -ne 0 ]; then
		echo -e "${RED}Building the package failed. Please check above. Reverting commits..."
		revertCommits
		echo -e "...done. Removing created files..."
		removeFiles
		echo -e "...done. Exiting.${NC}"
		exit -2
	fi
}


if [ -f "youtube-to-mp3_i386.deb" ]; then
	echo -e "${RED}Deleting existing 'youtube-to-mp3_i386.deb' file..${NC}"
	rm "youtube-to-mp3_i386.deb"
fi
if [ -f "youtube-to-mp3_x86_64.deb" ]; then
	echo -e "${RED}Deleting existing 'youtube-to-mp3_x86_64.deb' file..${NC}"
	rm "youtube-to-mp3_x86_64.deb"
fi

echo "The current date is: $(date --rfc-3339=date)"
if [ -f md5sum_i386 ]; then
	
	# Test, if the date in the md5sum File is existant and if so, if it equals the current date in rfc-3339 format
	if [ "$(cat md5sum_i386 | wc -l)" == "2" ]; then
		md5_date_i386="$(sed -n '2,2p' md5sum_i386)"
		if [ "$md5_date_i386" == "$(date --rfc-3339=date)" ]; then
			# If the date is the same, the file does not need to be updated. Proceed with the next one
			echo "MD5Sum for i386 Architecture is up to date."
			skip=true
		fi
	else
		# Set md5changes to true to absolutely push the md5sum Files, even if they are not with new checksums.
		md5_changes=true
	fi

	if [ "$skip" == "false" ]; then
		getSources_i386
		# Check for changes in the md5sum
		update_md5_i386
	fi
else
	# If the script is run for the first time, no md5sum File exists, so just create the file and upload it.
	# Download i386 source
	getSources_i386
	# Set md5changes to true to absolutely push the md5sum Files, even if they are not with new checksums.
	md5_changes=true
	# update md5sum
	update_md5_i386
fi

# Reset skip Value
skip=false
# Same for the 64-bit Version
if [ -f md5sum_x86_64 ]; then
	# Test, if date Line is in the File
	if [ "$(cat md5sum_x86_64 | wc -l)" == "2" ]; then
		md5_date_x86_64="$(sed -n '2,2p' md5sum_x86_64)"
		if [ "$md5_date_x86_64" == "$(date --rfc-3339=date)" ]; then
			# This md5sum is up to date, the date is the same.
			echo "MD5Sum for x86_64 Architecture is up to date."
			skip=true
		fi
	else
		date --rfc-3339=date >> md5sum_x86_64
		git add md5sum_x86_64
		git commit -m "$MSG_DATE_ADDED"
		# Set md5changes to true to absolutely push the md5sum Files, even if they are not with new checksums.
		md5_changes=true
	fi

	if [ "$skip" == "false" ]; then
		getSources_x86_64
		# Update the checksums
		update_md5_x86_64
	fi
else
	# If the script is run for the first time, no md5sum File exists, so just create the file and upload it.
	getSources_x86_64
	# update md5sum
	md5_changes=true
	update_md5_x86_64
fi

if [ $changes_made == "true" ]; then
	git checkout master
	# Get the pkgver Number and release Number from the PKGBUILD file
	pkgverline="$(cat PKGBUILD | grep pkgver= | head -1)"
	pkgrelline=$(cat PKGBUILD | grep 'pkgrel')
	pkgrel=${pkgrelline#*=}
	# Try making the package to ensure, that the checksums are correct and not faulty due to the internet connection or through stopping the script midway
	# This also updates the pkgver Number if it changed and resets the pkgrel Number to 1 in that case.
	buildPackage
	# Compare the Versionnumbers and count up the pkgrel number if they are still the same
	if [ $pkgverline == $(cat PKGBUILD | grep pkgver= | head -1) ]; then
		let "pkgrel++"
		pkgrelline="${pkgrelline%=*}=$pkgrel"
		sed -i "s/pkgrel=.\+/$pkgrelline/" PKGBUILD

		# Rebuild Package
		buildPackage
	elif (( pkgrel >= 2 )); then
		# Reset the pkgrel Number to one if the PKGBUILD script didn't do that by itself
		pkgrel=1
		pkgrelline="${pkgrelline%=*}=$pkgrel"
		sed -i "s/pkgrel=.\+/$pkgrelline/" PKGBUILD

		# Rebuild Package
		buildPackage
	fi
	# Update .SRCINFO
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
				exit -3
			fi
		elif [ "$answer" = "no" ] || [ "$answer" = "n" ]; then
			echo "Skipping AUR push.."
		else
			echo "Please Write one of the following and press enter: yes/no/y/n"
		fi
	done
	echo "Pushing PKGBUILD and .SRCINFO to home repository.."
	git push origin master
	if [ $? -ne 0 ]; then
		echo -e "${RED}Pushing failed. Please check for errors.${NC}"
		exit -3
	fi
fi

if [ "$md5_changes" == "true" ]; then
	# Now pushing the md5sums
	echo "Pushing the updated checksums to the home repository"
	git checkout update_script
	GIT_SSH_COMMAND='ssh -i ~/.ssh/id_rsa' git push
	echo "Push successful."
fi
removeFiles
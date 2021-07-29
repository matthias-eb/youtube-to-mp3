#!/bin/bash
## This script is for keeping the AUR package youtube-to-mp3 up to date with the md5sums.
## It automates the packaging, pushing and is keeping the files coherent. It updates the Checksums once per date.
##
## Exit states:
##	0: Everything went according to plan.
##	-1: Downloading the sources failed. This can happen due to no internet connection or a timeout.
##	-2: Packaging failed. Possibly the md5sum was not correct or another error occured.
##	-3: Pushing to remote Branch failed. Possibly faulty Files in the branch or a connection issue?
##
## The md5 checksum Files are located in the update_script branch.
## PKGBUILD and .SRCINFO are located in the master branch. This Branch is pushed to the aur and origin remote master branches.



BLACK="$(tput setaf 0)" # Black Foreground Color
RED="$(tput setaf 1)" # Red Foreground Color
GREEN="$(tput setaf 2)" # Green Foreground Color
BG_WHITE="$(tput setab 7)" # White Background
BOLD="$(tput bold)" # Bold font
RS="$(tput sgr 0)" # Reset Color and font

# Output Messages
OPT_PUSH_AUR="echo ${BOLD}==> Pushing to AUR remote repository...${RS}"
OPT_PUSH_MASTER="echo -e ${BOLD}==> Pushing to origin master branch...\t${RS}"
OPT_PUSH_UPDATE_SCRIPT="echo -e ${BOLD}==> Pushing to origin update_script branch...\t${RS}"
OPT_RESET="echo ${BOLD}${RED}${BG_WHITE}==> Removing commits:${RS}${BLACK}${BG_WHITE}" # Intro for the Resets. Keeps the White background to clarify what belongs to the Reset. Needs to be Reset afterwards
OPT_RESET_BRANCH="echo Resetting branch ${BOLD}$(git branch --show-current)${RS}${BLACK}${BG_WHITE}"
OPT_DATE_UPDATE_32="echo ${BOLD}==> 32 Checksum OK, refreshing date...${RS}"
OPT_DATE_UPDATE_64="echo ${BOLD}==> 64 Checksum OK, refreshing date...${RS}"
OPT_32_OK="echo ${BOLD}==> 32 Checksum OK${RS}"
OPT_32_DATE_SKIP="echo ${BOLD}==> 32 Bit checksum was already checked today. Skipping."
OPT_64_OK="echo ${BOLD}==> 64 Checksum OK${RS}"
OPT_64_DATE_SKIP="echo ${BOLD}==> 64 Bit checksum was already checked today. Skipping."
OPT_DONE="echo ${BOLD}==> ...done${RS}"
OPT_REM_FILES="echo ${BOLD}==> Removing created files.${RS}"
OPT_MD5_32_CHANGED="echo ${BOLD}${RED}==> Md5sum for Architecture i386 changed! Updating.${RS}"
OPT_MD5_64_CHANGED="echo ${BOLD}${RED}==> Md5sum for Architecture x86_64 changed! Updating.${RS}"
OPT_ERR_DOWNLOAD="echo ${BOLD}${RED}Downloading .deb File failed. Please check the error above. Maybe an internet connection is not established?${RS}"
OPT_ERR_BUILD_FAIL="echo ${BOLD}${RED}Building the package failed. Please check above. Reverting commits...${RS}"
OPT_ERR_PUSH="echo ${BOLD}${RED}Pushing failed. Please check above for errors.${RS}"
OPT_EXIT_SCRIPT="echo ${BOLD}Finished.${RS}"

MSG_32_SUM_CHANGED="32 Bit md5sum changed for PKGBUILD"
MSG_32_DATE_CHANGED="Date of the 32 Bit md5sum file changed"
MSG_64_SUM_CHANGED="64 Bit md5sum changed for PKGBUILD"
MSG_64_DATE_CHANGED="Date of the 64 Bit md5sum file changed"
MSG_DATE_ADDED="Date added for checksum File"

changes_made=false
skip=false
md5_changes=false
files_created=false
force=false


function checkUpstreamMD5Sums() {
	echo "=> Comparing MD5Sums from the AUR with the local files.."
	if [ "$(git branch --show-current)" != "aur/master" ]; then
		git checkout aur/master > /dev/null
	fi
	aur_md5_i386="$(cat PKGBUILD | grep "md5sums_i386" | cut -d'"' -f 2)"
	aur_md5_x86_64="$(cat PKGBUILD | grep "md5sums_x86_64" | cut -d'"' -f 2)"
	
	# Checkout update_script and compare the checksums
	git checkout update_script > /dev/null
	if [ "$aur_md5_i386" != "$(sed '1q;d' md5sum_i386 | cut -d' ' -f 1)" ]; then
		echo "The MD5sum for i386 Architecture is out of sync! Changing local MD5sum file..."
		md5file="$(sed '1q;d' md5sum_i386 | cut -d' ' -f 2)"
		sed -i "s/*${md5file}/${aur_md5_i386} ${md5file}/" md5sum_i386
	fi
	if [ "$aur_md5_x86_64" != "$(sed '1q;d' md5sum_x86_64 | cut -d' ' -f 1)" ]; then
		echo "The MD5sum for x86_64 Architecture is out of sync! Changing local MD5sum file..."
		md5file="$(sed '1q;d' md5sum_x86_64 | cut -d' ' -f 2)"
		sed -i "s/*${md5file}/${aur_md5_x86_64} ${md5file}/" md5sum_x86_64
	fi

}

function checkArguments() {
	echo "Checking $# arguments.."
	while [[ $# -gt 0 ]]
	do
		echo "Checking $1"
		option=$1
		case $option in 
			-f | --force)
			force="true"
			echo "Force option activated"
			;;
		esac
		shift	## shift Parameters to the left, $1 is now $2
	done
}

function output_new_commit() {
	echo "${BOLD}${GREEN}==> New Commit for branch $(git branch --show-current) created. Commit Message: $(git log -1 --format=format:%s)${RS}"
}

# This function resets all commits from today that have a Commit message, that this script inserted. 
# This means that this script will run again after fixing the problem that led to reverting the commits since the date commit is thrown away as well.
# This function prevents pushing wrong sha256 sums to the git repository.
function revertCommits() {
	# Remove hindering unversioned files 
	echo "Removing unneeded files and directories..."
	git clean -df
	### Change first to update_script branch
	# Change branch to update_script
	if [ "$(git branch --show-current)" != "update_script" ]; then
		git checkout update_script
	fi

	# Start white Background in console and Write first output
	$OPT_RESET
	for i in 1 2; do
		$OPT_RESET_BRANCH
		last_commit=$(git log -1 --format=format:%s)
		commit_date=$(git log -1 --date=short --format=format:%cd)
		# Remove the last commit as long as it has the current date and the commit Message matches one of the specified commit messages.
		while [ \( "$last_commit" = "$MSG_32_SUM_CHANGED" -o "$last_commit" = "$MSG_64_SUM_CHANGED" -o "$last_commit" = "$MSG_DATE_ADDED" \) -a \( "$commit_date" = "$(date --rfc-3339=date)" \) ]; do
			echo -e "\n------------------------------\n"
			git log -1 --format=fuller | cat
			git reset --hard HEAD~1
			
			last_commit=$(git log -1 --format=format:%s)
			commit_date=$(git log -1 --date=short --format=format:%cd)
		done
		git checkout master
		$OPT_RESET_BRANCH
	done
	echo "$RS"
	md5_changes=false
}

function removeFiles() {
	## Try to delete those Files while ignoring the output, if files were created
	if [ "$files_created" = "true" ]; then
		$OPT_REM_FILES

		rm youtube-to-mp3_i386.deb > /dev/null 2>&1
		rm youtube-to-mp3_x86_64.deb > /dev/null 2>&1
		rm *.pkg.tar.xz > /dev/null 2>&1
		rm *.pkg.tar.zst > /dev/null 2>&1
		rm *.part > /dev/null 2>&1
	fi
}

function getSources_i386() {
	# Download i386 source
	files_created=true
	wget --no-check-certificate -O "youtube-to-mp3_i386.deb" "https://www.mediahuman.com/de/download/YouTubeToMP3.i386.deb" # Download 32 Bit File
	if [ $? -ne 0 ]; then
		$OPT_ERR_DOWNLOAD
		removeFiles
		exit -1
	fi
}

function getSources_x86_64() {
	# Download sources for x86_64 Architecture
	files_created=true
	wget --no-check-certificate -O "youtube-to-mp3_x86_64.deb" "https://www.mediahuman.com/de/download/YouTubeToMP3.amd64.deb" # Download 64 Bit File
	if [ $? -ne 0 ]; then
		$OPT_ERR_DOWNLOAD
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
		if [ "$(date --rfc-3339=date)" != "$(sed '2q;d' md5sum_i386)" ] || [ "$force" = "true" ]; then
			$OPT_DATE_UPDATE_32
			# If the date does'nt match, replace the second line in the file with the new md5sum
			sed -i "2s/.*/$(date --rfc-3339=date)/" md5sum_i386
			git add md5sum_i386 > /dev/null
			git commit -m "$MSG_32_DATE_CHANGED" > /dev/null
			output_new_commit
			md5_changes=true
		else
			$OPT_32_OK
		fi
	else
		# The md5sum changed. We need to replace it in both the PKGBUILD and the md5sum file.
		# Change to the correct branch if necessary
		if [ "$(git branch --show-current)" != "master" ]; then
			git checkout master
		fi
		$OPT_MD5_32_CHANGED
		# Get the md5sum from the deb File
		md5_i386=$(md5sum "youtube-to-mp3_i386.deb" | cut -d ' ' -f 1)
		# Replace the first line in PKGBUILD starting with md5sums_i386=( with the same string and the added new md5sum as well as a ")"
		sed -i "s/md5sums_i386=(.\+/md5sums_i386=(\"${md5_i386}\")/" PKGBUILD
		# Set the flag to push the master branch of the aur and origin 
		changes_made=true
		git add PKGBUILD > /dev/null
		git commit -m "$MSG_32_SUM_CHANGED" > /dev/null

		# Now, rewrite the md5sum file and commit to the update_script branch as well 
		git checkout update_script
		md5sum "youtube-to-mp3_i386.deb" > md5sum_i386
		date --rfc-3339=date >> md5sum_i386
		git add md5sum_i386 > /dev/null
		git commit -m "$MSG_32_SUM_CHANGED" > /dev/null

		output_new_commit

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
		if [ "$(date --rfc-3339=date)" != "$(sed '2q;d' md5sum_x86_64)" ] || [ "$force" = "true" ]; then
			$OPT_DATE_UPDATE_64

			sed -i "2s/.*/$(date --rfc-3339=date)/" md5sum_x86_64
			git add md5sum_x86_64 > /dev/null
			git commit -m "$MSG_64_DATE_CHANGED" > /dev/null
			output_new_commit
			md5_changes=true
		else
			$OPT_64_OK
		fi
	else
		# The md5sum changed. We need to replace it in both the PKGBUILD and the md5sum file.
		# Change to the correct branch if necessary
		if [ "$(git branch --show-current)" != "master" ]; then
			git checkout master
		fi
		$OPT_MD5_64_CHANGED
		# Get the md5sum from the deb File
		md5_x86_64=$(md5sum "youtube-to-mp3_x86_64.deb" | cut -d ' ' -f 1)
		# Replace the first line in PKGBUILD starting with 'md5sums_x86_64=(' with that same string and the added new md5sum as well as a ')'"
		sed -i "s/md5sums_x86_64=(.\+/md5sums_x86_64=(\"${md5_x86_64}\")/" PKGBUILD
		# Set the flag to push the master branch of the aur and origin
		changes_made=true
		git add PKGBUILD > /dev/null
		git commit -m "$MSG_64_SUM_CHANGED" > /dev/null

		output_new_commit

		# Now, rewrite the md5sum file and commit to the update_script branch as well 
		git checkout update_script
		md5sum "youtube-to-mp3_x86_64.deb" > md5sum_x86_64
		date --rfc-3339=date >> md5sum_x86_64
		git add md5sum_x86_64 > /dev/null
		git commit -m "$MSG_64_SUM_CHANGED" > /dev/null
		output_new_commit
		# Set the flag to push to the update_script branch
		md5_changes=true
	fi
}

function buildPackage() {
	files_created=true
	makepkg -cf
	if [ $? -ne 0 ]; then
		$OPT_ERR_BUILD_FAIL
		revertCommits
		removeFiles
		exit -2
	fi
}


#### Main Script start ####


if [ -f "youtube-to-mp3_i386.deb" ]; then
	echo -e "${RED}Deleting existing 'youtube-to-mp3_i386.deb' file..${RS}"
	rm "youtube-to-mp3_i386.deb"
fi
if [ -f "youtube-to-mp3_x86_64.deb" ]; then
	echo -e "${RED}Deleting existing 'youtube-to-mp3_x86_64.deb' file..${RS}"
	rm "youtube-to-mp3_x86_64.deb"
fi

# Check for Options
checkArguments $@

checkUpstreamMD5Sums

echo "The current date is: $(date --rfc-3339=date)"
if [ -f md5sum_i386 ]; then
	
	# Test, if the date in the md5sum File is existant and if so, if it equals the current date in rfc-3339 format
	if [ "$(cat md5sum_i386 | wc -l)" == "2" ]; then
		md5_date_i386="$(sed -n '2,2p' md5sum_i386)"
		if [ "$md5_date_i386" == "$(date --rfc-3339=date)" ]; then
			# Skip date check if force option is active
			if [ "$force" != "true" ]; then
				# If the date is the same, the file does not need to be updated. Proceed with the next one
				$OPT_32_DATE_SKIP
				skip=true
			fi
		fi
	else
		# If the date line does not exist, add and commit it.
		date --rfc-3339=date >> md5sum_i386
		git add md5sum_i386 > /dev/null
		git commit -m "$MSG_DATE_ADDED" > /dev/null
		output_new_commit
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
			# Skip date check if force option is active
			if [ "$force" != "true" ]; then
				# This md5sum is up to date, the date is the same.
				$OPT_64_DATE_SKIP
				skip=true
			fi
		fi
	else
		# If the date line does not exist, add and commit it.
		date --rfc-3339=date >> md5sum_x86_64
		git add md5sum_x86_64 > /dev/null
		git commit -m "$MSG_DATE_ADDED" > /dev/null
		output_new_commit
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
	git commit -m ".SRCINFO regenerated, updated Package Version to ${pkgverline#*=} and Package Release Nr. to $pkgrel" > /dev/null
	output_new_commit

	# Update repository
	git status -sb
	echo "Do you want to publish the updated PKGBUILD and .SRCINFO to the AUR?"
	answer=""
	while [ "$answer" != "n" ] && [ "$answer" != "y" ] && [ "$answer" != "yes" ] && [ "$answer" != "no" ]; do
		read answer
		answer="${answer,,}"
		if [ "$answer" = "yes" ] || [ "$answer" = "y" ]; then
			$OPT_PUSH_AUR
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
	$OPT_PUSH_MASTER
	git push origin master
	if [ $? -ne 0 ]; then
		$OPT_ERR_PUSH
		exit -3
	fi
fi

if [ "$md5_changes" == "true" ]; then
	# Now pushing the md5sums
	$OPT_PUSH_UPDATE_SCRIPT
	git checkout update_script
	git push
	if [ $? -ne 0 ]; then
		$OPT_ERR_PUSH
		exit -3
	fi
fi
removeFiles
$OPT_EXIT_SCRIPT
TG_BOT_API_KEY=
TG_CHAT_ID=
username=

# Export variables
export KBUILD_BUILD_USER=
# export EXTENDED_BUILD_TYPE=OFFICIAL
# Colors makes things beautiful
export TERM=xterm

# Specify colors utilized in the terminal
red=$(tput setaf 1)                        #  red
grn=$(tput setaf 2)                        #  green
ylw=$(tput setaf 3)                        #  yellow
blu=$(tput setaf 4)                        #  blue
cya=$(tput rev)$(tput bold)$(tput setaf 6) #  bold cyan reversed
ylr=$(tput rev)$(tput bold)$(tput setaf 3) #  bold yellow reversed
grr=$(tput rev)$(tput bold)$(tput setaf 2) #  bold green reversed
rer=$(tput rev)$(tput bold)$(tput setaf 1) #  bold red reversed
txtrst=$(tput sgr0)                        #  Reset

[[ -z "${TG_BOT_API_KEY}" ]] && echo "BOT_API_KEY not defined, exiting!" && exit 1
function sendTG() {
	curl -s "https://api.telegram.org/bot${TG_BOT_API_KEY}/sendmessage" --data "text=${*}&chat_id=${TG_CHAT_ID}&parse_mode=Markdown" >/dev/null
}

# Check aex version
aex_check=$(grep -n "EXTENDED_VERSION" vendor/aosp/config/version.mk | grep -Eo '^[^:]+')
array=($aex_check)
AEX_VERSION=$(sed -n ${array[0]}'p' <vendor/aosp/config/version.mk | cut -d "=" -f 2 | tr -d '[:space:]')

if [ -z "$AEX_VERSION" ] || [ -z "$aex_check" ]; then
  echo -e ${red}"Couldn't detect AEX version exiting...."${txtrst};
  exit 1
fi

# Check need to repo sync
if [ "$repo_sync" = "yes" ]; then
repo sync -c -j$(nproc --all) --force-sync --no-clone-bundle --no-tags
fi

# Set default build_type to userdebug
device_build_type=aosp_${mydevice}-userdebug

# Check build type
if [ "$build_type" = "eng" ]; then
device_build_type=aosp_${mydevice}-eng
fi

# CCACHE UMMM!!! Cooks my builds fast
if [ "$use_ccache" = "yes" ];
then
echo -e ${blu}"CCACHE is enabled for this build"${txtrst}
export CCACHE_EXEC=$(which ccache)
export USE_CCACHE=1
export CCACHE_COMPRESS=1
export CCACHE_MAXSIZE=50G # 50 GB
fi

if [ "$use_ccache" = "clean" ];
then
export CCACHE_DIR=/home/$username/.ccache
ccache -C
wait
echo -e ${grn}"CCACHE Cleared"${txtrst};
fi

if [ "$use_gapps" = "yes" ];
then
export CURRENT_BUILD_TYPE=gapps
fi

source build/envsetup.sh

# Its Clean Time
if [ "$make_clean" = "yes" ];
then
make clean
wait
echo -e ${cya}"OUT dir from your repo deleted"${txtrst};
fi

# Rebuild
if [ "$make_clean" = "rebuild" ];
then
out=out/target/product/$mydevice
rm -f $out/*.zip $out/*Changelog* $out/*.md5sum $out/system/build.prop $out/obj/KERNEL_OBJ/.version >/dev/null
wait
echo -e ${cya}"Cleaning old build file......"${txtrst};
fi

if ! lunch "${device_build_type:?}"; then
	echo "Lunching $mydevice failed"
    sendTG "Lunching $mydevice failed."
	exit 1
fi

echo "${ylw}Initiating AEX ${AEX_VERSION} build for ${mydevice}...${txtrst}"
if ! make "$target_command" -j$(nproc --all); then
	echo "$mydevice build failed"
	sendTG "$mydevice build failed."
	exit 1
else
	cd out/target/product/$mydevice
	ZIP=$(ls AospExtended-${AEX_VERSION}-$mydevice-*.zip)
	ZIP_SIZE="$(du -h "${ZIP}" | awk '{print $1}')"
	MD5="$(md5sum "${ZIP}" | awk '{print $1}')"
	if [ "$upload_build" = true ]; then
		# Upload file
		GDRIVE_UPLOAD_URL=$(gdrive upload --share $ZIP | awk '/https/ {print $7}')
		GDRIVE_UPLOAD_ID="$(echo "${GDRIVE_UPLOAD_URL}" | sed -r -e 's/(.*)&export.*/\1/' -e 's/https.*id=(.*)/\1/' -e 's/https.*\/d\/(.*)\/view/\1/')"

        if [ -z "$GDRIVE_UPLOAD_URL" ] || [ -z "$GDRIVE_UPLOAD_ID" ]; then
            echo -e ${cya}"Couldn't upload build...."${txtrst};
            sendTG "$mydevice build is done, but couldn't upload."
        else
            UPLOAD_INFO="
			File: [$(basename "${ZIP}")](${GDRIVE_UPLOAD_URL})
			Size: ${ZIP_SIZE}
			MD5: \`${MD5}\`
			GDrive ID: \`${GDRIVE_UPLOAD_ID}\`"
		    sendTG "${UPLOAD_INFO}"
        fi
	else
		sendTG "$mydevice build is done."
	fi
fi

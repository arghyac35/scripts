TG_BOT_API_KEY=$BOT_API_KEY
TG_CHAT_ID=172556296

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
source "${SCRIPT_DIR}"/common

trap 'exit 1' INT TERM

# Create binaries directory
mkdir -p ~/bin/

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

DEVICE=$1
aex_check=$(grep -n "EXTENDED_VERSION" $SCRIPT_DIR/vendor/aosp/config/version.mk | grep -Eo '^[^:]+')
array=( $aex_check )
AEX_VERSION=$(sed -n ${array[0]}'p' < $SCRIPT_DIR/vendor/aosp/config/version.mk | cut -d "=" -f 2 | tr -d '[:space:]')

[[ -z "${TG_BOT_API_KEY}" ]] && echo "API_KEY not defined, exiting!" && exit 1
function sendTG() {
	curl -s "https://api.telegram.org/bot${TG_BOT_API_KEY}/sendmessage" --data "text=${*}&chat_id=${TG_CHAT_ID}&parse_mode=Markdown" >/dev/null
}

echo "${blu}Run repo sync?${txtrst}"
select yn in "Yes" "No"; do
	case $yn in
	Yes)
		repo sync -c -j$(nproc --all) --force-sync --no-clone-bundle --no-tags
		break
		;;
	No) break ;;
	esac
done

echo "${blu}Gapps or Non-gapps Build?${txtrst}"
select yn in "gapps" "nongapps"; do
	case $yn in
	gapps)
		export CURRENT_BUILD_TYPE=gapps
		break
		;;
	nongapps)
		export CURRENT_BUILD_TYPE=xyzzzz
		break
		;;
	esac
done

echo "Upload compilation to remote server at end of build?"
set_upload_build=false
select yn in "Yes" "No"; do
	case $yn in
	Yes)
		set_upload_build=true
		break
		;;
	No)
		set_upload_build=false
		break
		;;
	esac
done

if [ "$set_upload_build" = true ]; then
	echo 'Please choose where to upload your build: '
	options=("Gdrive" "Source Forge")
	select opt in "${options[@]}"; do
		case $opt in
		"Gdrive")
			set_upload_build_server="gdrive"
			echo "Checking gdrive installed or not"
			GDRIVE="$(command -v gdrive)"
			if [ -z "${GDRIVE}" ]; then
				echo "Installing gdrive"
				# Install standard packages.
				echoText "Installing necessary packages"
				sudo apt install -y aria2 jq

				bash -i "${SCRIPT_DIR}"/gdrive.sh
			else
				INSTALLED_VERSION="$(gdrive version | grep gdrive | awk '{print $2}')"
				reportWarning "gdrive ${INSTALLED_VERSION} is already installed!"
			fi
			break
			;;
		"Source Forge")
			echo "Comming soon..."
			# echo "Enter remote hostname (ex: web.sourceforge.net): "
			# read set_remote_hostname
			# echo "Enter remote username:"
			# read set_remote_username
			# echo "Enter remote password:"
			# read set_remote_password
			break
			;;
		esac
	done
fi

echo "${blu}Make clean build?${txtrst}"
select yn in "yes" "no"; do
	case $yn in
	yes)
		. build/envsetup.sh && make clean
		break
		;;
	no) break ;;
	esac
done

echo "${blu}Select Build Type?${txtrst}"
select yn in "eng" "userdebug"; do
	case $yn in
	eng)
		device_build_type=aosp_${DEVICE}-eng
		break
		;;
	userdebug)
		device_build_type=aosp_${DEVICE}-userdebug
		break
		;;
	esac
done
export CCACHE_EXEC=$(which ccache)
export USE_CCACHE=1
export CCACHE_COMPRESS=1
export CCACHE_MAXSIZE=50G # 50 GB
if ! lunch "${device_build_type:?}"; then
	echo "Lunching $DEVICE failed"
	exit 1
fi

echo "${blu}Please confirm do you want to start build?${txtrst}"
select yn in "yes" "no"; do
	case $yn in
	yes)
		echo "${ylw}Initiate build for ${DEVICE}...${txtrst}"
		if ! mka aex; then
			echo "$DEVICE Build failed"
			exit 1
		fi
		cout
		ZIP=$(ls AospExtended-${AEX_VERSION}-$DEVICE-*.zip)
		ZIP_SIZE="$(du -h "${ZIP}" | awk '{print $1}')"
		MD5="$(md5sum "${FILE}" | awk '{print $1}')"
		if [ "$set_upload_build" = true -a "$set_upload_build_server" == "gdrive" ]; then
			# Upload file
			GDRIVE_UPLOAD_URL=$(gdrive upload --share $ZIP | awk '/https/ {print $7}')
			GDRIVE_UPLOAD_ID="$(echo "${GDRIVE_UPLOAD_URL}" | sed -r -e 's/(.*)&export.*/\1/' -e 's/https.*id=(.*)/\1/' -e 's/https.*\/d\/(.*)\/view/\1/')"
			UPLOAD_INFO="
File: [$(basename "${ZIP}")](${GDRIVE_UPLOAD_URL})
Size: ${ZIP_SIZE}
MD5: \`${MD5}\`
GDrive ID: \`${GDRIVE_UPLOAD_ID}\`
"
			sendTG "${UPLOAD_INFO}"
		else
			sendTG "$DEVICE build is done."
		fi
		break
		;;
	no) break ;;
	esac
done

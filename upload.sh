TG_BOT_API_KEY=$BOT_API_KEY
TG_CHAT_ID=172556296
DEVICE=whyred

#read configuration
source config.conf

[[ -z "${TG_BOT_API_KEY}" ]] && echo "BOT_API_KEY not defined, exiting!" && exit 1
function sendTG() {
	curl -s "https://api.telegram.org/bot${TG_BOT_API_KEY}/sendmessage" --data "text=${*}&chat_id=${TG_CHAT_ID}&parse_mode=Markdown" >/dev/null
}

cd $aex_path

# Check aex version
aex_check=$(grep -n "EXTENDED_VERSION" $aex_path/vendor/aosp/config/version.mk | grep -Eo '^[^:]+')
array=($aex_check)
AEX_VERSION=$(sed -n ${array[0]}'p' <$aex_path/vendor/aosp/config/version.mk | cut -d "=" -f 2 | tr -d '[:space:]')

cd $aex_path/out/target/product/$DEVICE
ZIP=$(ls AospExtended-${AEX_VERSION}-$DEVICE-*.zip)
ZIP_SIZE="$(du -h "${ZIP}" | awk '{print $1}')"
MD5="$(md5sum "${ZIP}" | awk '{print $1}')"
if [ "$set_upload_build" = true -a "$set_upload_build_server" == "gdrive" ]; then
	# Upload file
	GDRIVE_UPLOAD_URL=$(sudo gdrive upload --share $ZIP | awk '/https/ {print $7}')
	GDRIVE_UPLOAD_ID="$(echo "${GDRIVE_UPLOAD_URL}" | sed -r -e 's/(.*)&export.*/\1/' -e 's/https.*id=(.*)/\1/' -e 's/https.*\/d\/(.*)\/view/\1/')"
	UPLOAD_INFO="
		File: [$(basename "${ZIP}")](${GDRIVE_UPLOAD_URL})
		Size: ${ZIP_SIZE}
		MD5: \`${MD5}\`
		GDrive ID: \`${GDRIVE_UPLOAD_ID}\`"
	sendTG "${UPLOAD_INFO}"
else
	sendTG "$DEVICE build is done."
fi

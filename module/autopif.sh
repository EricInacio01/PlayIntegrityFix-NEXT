#!/bin/sh

PATH=/data/adb/ap/bin:/data/adb/ksu/bin:/data/adb/magisk:/data/data/com.termux/files/usr/bin:$PATH
MODDIR=/data/adb/modules/playintegrityfix
version=$(grep "^version=" $MODDIR/module.prop | sed 's/version=//g')

. $MODDIR/common_func.sh

# lets try to use tmpfs for processing
TEMPDIR="$MODDIR/temp" #fallback
[ -w /sbin ] && TEMPDIR="/sbin/playintegrityfix"
[ -w /debug_ramdisk ] && TEMPDIR="/debug_ramdisk/playintegrityfix"
[ -w /dev ] && TEMPDIR="/dev/playintegrityfix"
mkdir -p "$TEMPDIR"
cd "$TEMPDIR"

echo "[+] PlayIntegrityFix $version"
echo "[+] $(basename "$0")"
printf "\n\n"

set_random_beta() {
	if [ "$(echo "$MODEL_LIST" | wc -l)" -ne "$(echo "$PRODUCT_LIST" | wc -l)" ]; then
		echo "Warning: MODEL_LIST and PRODUCT_LIST have different lengths, using Pixel 6 fallback"
		MODEL="Pixel 6"
		PRODUCT="oriole_beta"
	else
		count=$(echo "$MODEL_LIST" | wc -l)
		rand_index=$(( $$ % count ))
		MODEL=$(echo "$MODEL_LIST" | sed -n "$((rand_index + 1))p")
		PRODUCT=$(echo "$PRODUCT_LIST" | sed -n "$((rand_index + 1))p")
	fi
}

get_model_product_list() {
	printf "{\"model\":["
	count=0
	total=$(echo "$MODEL_LIST" | wc -l)
	echo "$MODEL_LIST" | while read -r model; do
		count=$((count + 1))
		printf "\"%s\"" "$model"
		[ $count -lt $total ] && printf ","
	done
	printf "],\"product\":["
	count=0
	total=$(echo "$PRODUCT_LIST" | wc -l)
	echo "$PRODUCT_LIST" | while read -r product; do
		count=$((count + 1))
		printf "\"%s\"" "$product"
		[ $count -lt $total ] && printf ","
	done
	printf "]}"

	rm -rf "$TEMPDIR"
	exit 0
}

# Get latest Pixel Beta information
download https://developer.android.com/about/versions PIXEL_VERSIONS_HTML
BETA_URL=$(grep -o 'https://developer.android.com/about/versions/.*[0-9]"' PIXEL_VERSIONS_HTML | sort -ru | cut -d\" -f1 | head -n1)
download "$BETA_URL" PIXEL_LATEST_HTML

# Get OTA information
OTA_URL="https://developer.android.com$(grep -o 'href=".*download-ota.*"' PIXEL_LATEST_HTML | grep 'qpr' | cut -d\" -f2 | head -n1)"
download "$OTA_URL" PIXEL_OTA_HTML

# Extract device information
MODEL_LIST="$(grep -A1 'tr id=' PIXEL_OTA_HTML | grep 'td' | sed 's;.*<td>\(.*\)</td>;\1;')"
PRODUCT_LIST="$(grep -o 'tr id="[^"]*"' PIXEL_OTA_HTML | awk -F\" '{print $2 "_beta"}')"
OTA_LIST="$(grep 'ota/.*_beta' PIXEL_OTA_HTML | cut -d\" -f2)"

# List available devices
if [ "$1" = "--list" ] || [ "$1" = "-l" ]; then
	get_model_product_list
fi

# Select and configure device
echo "- Selecting Pixel Beta device ..."
[ -z "$PRODUCT" ] && set_random_beta
echo "$MODEL ($PRODUCT)"

# Get device fingerprint and security patch from OTA metadata
OTA_LINK="$(echo "$OTA_LIST" | grep "$PRODUCT")"
if command -v curl > /dev/null 2>&1; then
	curl --connect-timeout 10 -s "$OTA_LINK" | strings | head -n15 > PIXEL_ZIP_METADATA || download_fail "$OTA_LINK"
else
	busybox wget -T 10 --no-check-certificate -qO - "$OTA_LINK" | strings | head -n15 > PIXEL_ZIP_METADATA || download_fail "$OTA_LINK"
fi
FINGERPRINT="$(grep -am1 'post-build=' PIXEL_ZIP_METADATA | cut -d= -f2)"
SECURITY_PATCH="$(grep -am1 'security-patch-level=' PIXEL_ZIP_METADATA | cut -d= -f2)"

# Validate required field to prevent empty pif.prop
if [ -z "$FINGERPRINT" ] || [ -z "$SECURITY_PATCH" ]; then
	# link to download pixel rom metadata
	download_fail "https://dl.google.com"
fi

# Preserve previous setting
spoofConfig="spoofBuild spoofProps spoofProvider spoofSignature spoofVendingBuild spoofVendingSdk DEBUG"
for config in $spoofConfig; do
	if grep -q "$config=true" "$MODDIR/pif.prop"; then
		eval "$config=true"
	else
		eval "$config=false"
	fi
done

echo "- Dumping values to pif.prop ..."
echo ""
cat <<EOF | tee pif.prop
FINGERPRINT=$FINGERPRINT
MANUFACTURER=Google
MODEL=$MODEL
SECURITY_PATCH=$SECURITY_PATCH
spoofBuild=$spoofBuild
spoofProps=$spoofProps
spoofProvider=$spoofProvider
spoofSignature=$spoofSignature
spoofVendingBuild=$spoofVendingBuild
spoofVendingSdk=$spoofVendingSdk
DEBUG=$DEBUG
EOF

cat "$TEMPDIR/pif.prop" > /data/adb/pif.prop
echo ""
echo "- new pif.prop saved to /data/adb/pif.prop"

echo "- Cleaning up ..."
rm -rf "$TEMPDIR"

for i in $(busybox pidof com.google.android.gms.unstable com.android.vending); do
	echo "- Killing pid $i"
	kill -9 "$i"
done

echo "- Done!"
sleep_pause

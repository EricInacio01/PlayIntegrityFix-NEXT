#!/bin/sh

# ----------------------------
# PlayIntegrityFix-NEXT : autopif.sh
# Credits: osm0sis, for this original work
# I Made some improvements
# Synced: 2025/08/08
# ----------------------------

PATH=/data/adb/ap/bin:/data/adb/ksu/bin:/data/adb/magisk:/data/data/com.termux/files/usr/bin:$PATH

MODDIR=/data/adb/modules/playintegrityfix
version=$(grep "^version=" $MODDIR/module.prop | sed 's/version=//g')
FORCE_PREVIEW=1  # Set to 1 to include Developer Preview builds

TEMPDIR="$MODDIR/temp"
[ -w /sbin ] && TEMPDIR="/sbin/playintegrityfix"
[ -w /debug_ramdisk ] && TEMPDIR="/debug_ramdisk/playintegrityfix"
[ -w /dev ] && TEMPDIR="/dev/playintegrityfix"
mkdir -p "$TEMPDIR"
cd "$TEMPDIR"

echo "✅ PIF-Next: Version $version"
echo "🚀 Executing: $(basename "$0")"
printf "\n\n"

sleep_pause() {
    if [ -z "$MMRL" ] && [ -z "$KSU_NEXT" ] && { [ "$KSU" = "true" ] || [ "$APATCH" = "true" ]; }; then
        sleep 5
    fi
}

download_fail() {
    dl_domain=$(echo "$1" | awk -F[/:] '{print $4}')
    echo "$1" | grep -q "\.zip$" && return 
    
    rm -rf "$TEMPDIR"
    ping -c 1 -W 5 "$dl_domain" > /dev/null 2>&1 || {
        echo "❌ Unable to connect to $dl_domain. Please check your internet connection and try again."
        sleep_pause
        exit 1
    }
    
    conflict_module=$(ls /data/adb/modules | grep busybox)
    for i in $conflict_module; do 
        echo "⚠️ Conflict detected: Please remove $i and try again."
    done
    
    echo "❌ Download failed!"
    echo "🛑 Aborting operation!"
    sleep_pause
    exit 1
}

download() { busybox wget -T 10 --no-check-certificate -qO - "$1" > "$2" || download_fail "$1"; }
if command -v curl > /dev/null 2>&1; then
    download() { curl --connect-timeout 10 -s "$1" > "$2" || download_fail "$1"; }
fi

set_random_beta() {
    if [ "$(echo "$MODEL_LIST" | wc -l)" -ne "$(echo "$PRODUCT_LIST" | wc -l)" ]; then
        echo "❌ Error: MODEL_LIST and PRODUCT_LIST have different lengths."
        sleep_pause
        exit 1
    fi
    count=$(echo "$MODEL_LIST" | wc -l)
    rand_index=$(( $$ % count )) 
    MODEL=$(echo "$MODEL_LIST" | sed -n "$((rand_index + 1))p")
    PRODUCT=$(echo "$PRODUCT_LIST" | sed -n "$((rand_index + 1))p")
}

echo "📡 Retrieving Pixel beta data from Android Developer site..."
download https://developer.android.com/about/versions PIXEL_VERSIONS_HTML
BETA_URL=$(grep -o 'https://developer.android.com/about/versions/.*[0-9]"' PIXEL_VERSIONS_HTML | sort -ru | cut -d\" -f1 | head -n1)
download "$BETA_URL" PIXEL_LATEST_HTML

if grep -qE 'Developer Preview|tooltip>.*preview program' PIXEL_LATEST_HTML && [ "$FORCE_PREVIEW" = 0 ]; then
    echo "🔄 Using stable beta (skipping preview build)"
    BETA_URL=$(grep -o 'https://developer.android.com/about/versions/.*[0-9]"' PIXEL_VERSIONS_HTML | sort -ru | cut -d\" -f1 | head -n2 | tail -n1)
    download "$BETA_URL" PIXEL_BETA_HTML
else
    echo "🛠️ Including Developer Preview builds"
    mv -f PIXEL_LATEST_HTML PIXEL_BETA_HTML
fi

OTA_URL="https://developer.android.com$(grep -o 'href=".*download-ota.*"' PIXEL_BETA_HTML | cut -d\" -f2 | head -n1)"
download "$OTA_URL" PIXEL_OTA_HTML

MODEL_LIST="$(grep -A1 'tr id=' PIXEL_OTA_HTML | grep 'td' | sed 's;.*<td>\(.*\)</td>;\1;')"
PRODUCT_LIST="$(grep -o 'ota/.*_beta' PIXEL_OTA_HTML | cut -d\/ -f2)"
OTA_LIST="$(grep 'ota/.*_beta' PIXEL_OTA_HTML | cut -d\" -f2)"

echo "📱 Selecting Pixel Beta device..."
[ -z "$PRODUCT" ] && set_random_beta
echo "✅ Selected: $MODEL ($PRODUCT)"

echo "🔍 Fetching device fingerprint..."
(ulimit -f 2; download "$(echo "$OTA_LIST" | grep "$PRODUCT")" PIXEL_ZIP_METADATA) >/dev/null 2>&1

FINGERPRINT="$(strings PIXEL_ZIP_METADATA | grep -am1 'post-build=' | cut -d= -f2)"
SECURITY_PATCH="$(strings PIXEL_ZIP_METADATA | grep -am1 'security-patch-level=' | cut -d= -f2)"

if [ -z "$FINGERPRINT" ] || [ -z "$SECURITY_PATCH" ]; then
    echo "❌ Critical data missing in metadata"
    download_fail "https://dl.google.com"
fi

echo "⚙️ Maintaining previous module settings..."
spoofConfig="spoofBuild spoofProvider spoofProps spoofSignature DEBUG spoofVendingSdk"
for config in $spoofConfig; do
    if grep -q "\"$config\": true" "$MODDIR/pif.json"; then
        eval "$config=true"
    else
        eval "$config=false"
    fi
done

echo "📝 Generating updated pif.json..."
cat <<EOF | tee pif.json
{
  "FINGERPRINT": "$FINGERPRINT",
  "MANUFACTURER": "Google",
  "MODEL": "$MODEL",
  "SECURITY_PATCH": "$SECURITY_PATCH",
  "spoofBuild": $spoofBuild,
  "spoofProvider": $spoofProvider,
  "spoofProps": $spoofProps,
  "spoofSignature": $spoofSignature,
  "DEBUG": $DEBUG,
  "spoofVendingSdk": $spoofVendingSdk
}
EOF

cat "$TEMPDIR/pif.json" > /data/adb/pif.json
echo "💾 New configuration saved to /data/adb/pif.json"

echo "🧹 Cleaning temporary files..."
rm -rf "$TEMPDIR"

if [ -f /data/adb/modules/playintegrityfix/killpi.sh ]; then
    echo "🔄 Killing any running GMS DroidGuard/Play Store processes..."
    sh /data/adb/modules/playintegrityfix/killpi.sh >/dev/null 2>&1 || {
        echo "⚠️ killpi.sh encountered issues but proceeding anyway"
        true
    }
fi

echo "🎉 Operation completed successfully!"
sleep_pause
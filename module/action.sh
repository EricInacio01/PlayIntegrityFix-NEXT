#!/bin/sh

# PIF-Next: Fingerprint Update Script
# This script downloads and applies the latest fingerprint and security patch
# from Google's Pixel OTA metadata. It is compatible with KSU, APatch, Magisk,
# and Termux environments. It preserves prior spoofing configurations.

# --------------------------------------------------------------------------------------

PATH=/data/adb/ap/bin:/data/adb/ksu/bin:/data/adb/magisk:/data/data/com.termux/files/usr/bin:$PATH

# Module directory and version extraction
MODDIR=/data/adb/modules/playintegrityfix
version=$(grep "^version=" $MODDIR/module.prop | sed 's/version=//g')
FORCE_PREVIEW=1  # Set to 1 to include Developer Preview builds

# Configure temporary working directory (prioritizing writable system locations)
TEMPDIR="$MODDIR/temp"  # Primary fallback
[ -w /sbin ] && TEMPDIR="/sbin/playintegrityfix"
[ -w /debug_ramdisk ] && TEMPDIR="/debug_ramdisk/playintegrityfix"
[ -w /dev ] && TEMPDIR="/dev/playintegrityfix"
mkdir -p "$TEMPDIR"
cd "$TEMPDIR"

echo "[+] PIF-Next: $version"
echo "[+] Executing: $(basename "$0")"
printf "\n\n"

# Conditional pause for specific root implementations
sleep_pause() {
    # Required for APatch/KernelSU (except KSU_NEXT/MMRL environments)
    if [ -z "$MMRL" ] && [ -z "$KSU_NEXT" ] && { [ "$KSU" = "true" ] || [ "$APATCH" = "true" ]; }; then
        sleep 5
    fi
}

# Handle download failure scenarios
download_fail() {
    dl_domain=$(echo "$1" | awk -F[/:] '{print $4}')
    echo "$1" | grep -q "\.zip$" && return  # Skip cleanup for ZIPs
    
    rm -rf "$TEMPDIR"  # Purge temporary files
    
    # Network connectivity check
    ping -c 1 -W 5 "$dl_domain" > /dev/null 2>&1 || {
        echo "[!] Unable to connect to $dl_domain, please check your internet connection and try again"
        sleep_pause
        exit 1
    }
    
    # Detect conflicting busybox modules
    conflict_module=$(ls /data/adb/modules | grep busybox)
    for i in $conflict_module; do 
        echo "[!] Conflict detected: Please remove $i and try again." 
    done
    
    echo "[!] Download failed!"
    echo "[x] Aborting operation!"
    sleep_pause
    exit 1
}

# Download handler with wget/curl fallback
download() { busybox wget -T 10 --no-check-certificate -qO - "$1" > "$2" || download_fail "$1"; }
if command -v curl > /dev/null 2>&1; then
    download() { curl --connect-timeout 10 -s "$1" > "$2" || download_fail "$1"; }
fi

# Random beta device selection from parallel lists
set_random_beta() {
    if [ "$(echo "$MODEL_LIST" | wc -l)" -ne "$(echo "$PRODUCT_LIST" | wc -l)" ]; then
        echo "Error: MODEL_LIST and PRODUCT_LIST have different lengths."
        sleep_pause
        exit 1
    fi
    count=$(echo "$MODEL_LIST" | wc -l)
    rand_index=$(( $$ % count ))  # PID-based randomization
    MODEL=$(echo "$MODEL_LIST" | sed -n "$((rand_index + 1))p")
    PRODUCT=$(echo "$PRODUCT_LIST" | sed -n "$((rand_index + 1))p")
}

# Fetch latest Pixel beta information
echo "- Retrieving Pixel beta data from Android Developer site..."
download https://developer.android.com/about/versions PIXEL_VERSIONS_HTML
BETA_URL=$(grep -o 'https://developer.android.com/about/versions/.*[0-9]"' PIXEL_VERSIONS_HTML | sort -ru | cut -d\" -f1 | head -n1)
download "$BETA_URL" PIXEL_LATEST_HTML

# Handle Developer Preview/Beta selection logic
if grep -qE 'Developer Preview|tooltip>.*preview program' PIXEL_LATEST_HTML && [ "$FORCE_PREVIEW" = 0 ]; then
    echo "- Using stable beta (skip preview build)"
    BETA_URL=$(grep -o 'https://developer.android.com/about/versions/.*[0-9]"' PIXEL_VERSIONS_HTML | sort -ru | cut -d\" -f1 | head -n2 | tail -n1)
    download "$BETA_URL" PIXEL_BETA_HTML
else
    echo "- Including Developer Preview builds"
    mv -f PIXEL_LATEST_HTML PIXEL_BETA_HTML
fi

# Extract OTA information from beta page
OTA_URL="https://developer.android.com$(grep -o 'href=".*download-ota.*"' PIXEL_BETA_HTML | cut -d\" -f2 | head -n1)"
download "$OTA_URL" PIXEL_OTA_HTML

# Parse device model and product lists
MODEL_LIST="$(grep -A1 'tr id=' PIXEL_OTA_HTML | grep 'td' | sed 's;.*<td>\(.*\)</td>;\1;')"
PRODUCT_LIST="$(grep -o 'ota/.*_beta' PIXEL_OTA_HTML | cut -d\/ -f2)"
OTA_LIST="$(grep 'ota/.*_beta' PIXEL_OTA_HTML | cut -d\" -f2)"

# Device selection logic
echo "- Selecting Pixel Beta device..."
[ -z "$PRODUCT" ] && set_random_beta
echo "$MODEL ($PRODUCT)"

# Download OTA metadata (with size limit to prevent large files)
echo "- Fetching device fingerprint..."
(ulimit -f 2; download "$(echo "$OTA_LIST" | grep "$PRODUCT")" PIXEL_ZIP_METADATA) >/dev/null 2>&1

# Extract critical device identifiers
FINGERPRINT="$(strings PIXEL_ZIP_METADATA | grep -am1 'post-build=' | cut -d= -f2)"
SECURITY_PATCH="$(strings PIXEL_ZIP_METADATA | grep -am1 'security-patch-level=' | cut -d= -f2)"

# Validate extracted data
if [ -z "$FINGERPRINT" ] || [ -z "$SECURITY_PATCH" ]; then
    echo "[!] Critical data missing in metadata"
    download_fail "https://dl.google.com"  # Trigger standard failure handling
fi

# Preserve existing configuration flags
echo "- Maintaining previous module settings..."
spoofConfig="spoofProvider spoofProps spoofSignature DEBUG spoofVendingSdk"
for config in $spoofConfig; do
    if grep -q "\"$config\": true" "$MODDIR/pif.json"; then
        eval "$config=true"
    else
        eval "$config=false"
    fi
done

# Generate new configuration file
echo "- Generating updated pif.json..."
cat <<EOF | tee pif.json
{
  "FINGERPRINT": "$FINGERPRINT",
  "MANUFACTURER": "Google",
  "MODEL": "$MODEL",
  "SECURITY_PATCH": "$SECURITY_PATCH",
  "spoofProvider": $spoofProvider,
  "spoofProps": $spoofProps,
  "spoofSignature": $spoofSignature,
  "DEBUG": $DEBUG,
  "spoofVendingSdk": $spoofVendingSdk
}
EOF

# Deploy new configuration
cat "$TEMPDIR/pif.json" > /data/adb/pif.json
echo "- New configuration saved to /data/adb/pif.json"

# Cleanup temporary resources
echo "- Cleaning temporary files..."
rm -rf "$TEMPDIR"

# Restart Google Play Services
echo "- Restarting Google Play Services..."
for i in $(busybox pidof com.google.android.gms.unstable); do
    kill -9 "$i"
done

echo "- Operation completed successfully!"
sleep_pause
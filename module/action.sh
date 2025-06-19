#!/bin/sh

# PIF-Next: Fingerprint Update Script
# This script downloads and applies the latest fingerprint and security patch
# from Google's Pixel OTA metadata. It is compatible with KSU, APatch, Magisk,
# and Termux environments. It preserves prior spoofing configurations.

PATH=/data/adb/ap/bin:/data/adb/ksu/bin:/data/adb/magisk:/data/data/com.termux/files/usr/bin:$PATH
MODDIR=/data/adb/modules/playintegrityfix
version=$(grep "^version=" "$MODDIR/module.prop" | cut -d= -f2)
FORCE_PREVIEW=1

# Attempt to use high-priority writable temp directory
TEMPDIR="$MODDIR/temp"
[ -w /sbin ] && TEMPDIR="/sbin/playintegrityfix"
[ -w /debug_ramdisk ] && TEMPDIR="/debug_ramdisk/playintegrityfix"
[ -w /dev ] && TEMPDIR="/dev/playintegrityfix"
mkdir -p "$TEMPDIR"
cd "$TEMPDIR"

# Banner
echo "[+] PIF-Next version: $version"
echo "[+] Running: $(basename "$0")"
echo

# Helper: Sleep pause for some environments
sleep_pause() {
	if [ -z "$MMRL" ] && [ -z "$KSU_NEXT" ] && { [ "$KSU" = "true" ] || [ "$APATCH" = "true" ]; }; then
		sleep 5
	fi
}

# Helper: Handle download failure
download_fail() {
	domain=$(echo "$1" | awk -F[/:] '{print $4}')
	echo "$1" | grep -q "\.zip$" && return
	rm -rf "$TEMPDIR"
	ping -c 1 -W 5 "$domain" >/dev/null 2>&1 || {
		echo "[!] Cannot connect to $domain. Check your network."
		sleep_pause
		exit 1
	}
	conflict_module=$(ls /data/adb/modules | grep busybox)
	for m in $conflict_module; do echo "[!] Conflict: remove module $m"; done
	echo "[!] Download failed. Aborting."
	sleep_pause
	exit 1
}

# Helper: Download using curl or fallback to wget
if command -v curl >/dev/null 2>&1; then
	download() { curl --connect-timeout 10 -s "$1" > "$2" || download_fail "$1"; }
else
	download() { busybox wget -T 10 --no-check-certificate -qO - "$1" > "$2" || download_fail "$1"; }
fi

# Helper: Random beta picker
set_random_beta() {
	[ "$(echo "$MODEL_LIST" | wc -l)" -ne "$(echo "$PRODUCT_LIST" | wc -l)" ] && {
		echo "[!] MODEL_LIST and PRODUCT_LIST length mismatch"; sleep_pause; exit 1; }
	rand_index=$(( $$ % $(echo "$MODEL_LIST" | wc -l) ))
	MODEL=$(echo "$MODEL_LIST" | sed -n "$((rand_index + 1))p")
	PRODUCT=$(echo "$PRODUCT_LIST" | sed -n "$((rand_index + 1))p")
}

# Download and parse Android beta pages
echo "[*] Fetching latest Android beta info..."
download https://developer.android.com/about/versions PIXEL_VERSIONS_HTML
BETA_URL=$(grep -o 'https://developer.android.com/about/versions/.*[0-9]"' PIXEL_VERSIONS_HTML | sort -ru | cut -d\" -f1 | head -n1)
download "$BETA_URL" PIXEL_LATEST_HTML

if grep -qE 'Developer Preview|tooltip>.*preview program' PIXEL_LATEST_HTML && [ "$FORCE_PREVIEW" = 0 ]; then
	BETA_URL=$(grep -o 'https://developer.android.com/about/versions/.*[0-9]"' PIXEL_VERSIONS_HTML | sort -ru | cut -d\" -f1 | head -n2 | tail -n1)
	download "$BETA_URL" PIXEL_BETA_HTML
else
	mv -f PIXEL_LATEST_HTML PIXEL_BETA_HTML
fi

# Extract OTA and device info
OTA_URL="https://developer.android.com$(grep -o 'href=".*download-ota.*"' PIXEL_BETA_HTML | cut -d\" -f2 | head -n1)"
download "$OTA_URL" PIXEL_OTA_HTML

MODEL_LIST=$(grep -A1 'tr id=' PIXEL_OTA_HTML | grep 'td' | sed 's;.*<td>\(.*\)</td>;\1;')
PRODUCT_LIST=$(grep -o 'ota/.*_beta' PIXEL_OTA_HTML | cut -d/ -f2)
OTA_LIST=$(grep 'ota/.*_beta' PIXEL_OTA_HTML | cut -d\" -f2)

[ -z "$PRODUCT" ] && set_random_beta

echo "[*] Selected device: $MODEL ($PRODUCT)"
download "https://dl.google.com/$(echo "$OTA_LIST" | grep "$PRODUCT")" PIXEL_ZIP_METADATA

FINGERPRINT=$(strings PIXEL_ZIP_METADATA | grep -am1 'post-build=' | cut -d= -f2)
SECURITY_PATCH=$(strings PIXEL_ZIP_METADATA | grep -am1 'security-patch-level=' | cut -d= -f2)

[ -z "$FINGERPRINT" ] || [ -z "$SECURITY_PATCH" ] && download_fail "https://dl.google.com"

# Preserve previous spoof settings
spoofConfig="spoofProvider spoofProps spoofSignature DEBUG spoofVendingSdk"
for config in $spoofConfig; do
	if grep -q "\"$config\": true" "$MODDIR/pif.json" 2>/dev/null; then
		eval "$config=true"
	else
		eval "$config=false"
	fi
done

# Generate and write new pif.json
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

cp -f pif.json /data/adb/pif.json

# Kill GMS to apply changes
for pid in $(busybox pidof com.google.android.gms.unstable 2>/dev/null); do
	echo "[*] Killing GMS PID $pid"
	kill -9 "$pid"
done

# Cleanup
rm -rf "$TEMPDIR"
echo "[+] Done. New fingerprint applied."
sleep_pause
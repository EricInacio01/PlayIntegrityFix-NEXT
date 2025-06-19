#!/system/bin/sh

set -e

PATH=/data/adb/ap/bin:/data/adb/ksu/bin:/data/adb/magisk:$PATH
MODDIR=/data/adb/modules/playintegrityfix
TEMPDIR="$MODDIR/temp"
mkdir -p "$TEMPDIR"
cd "$TEMPDIR"

echo "[+] PIF-Next action initiated."

# ========== Utility ==========
die() { echo "[!] $1"; exit 1; }
download_fail() {
    echo "[!] Failed to download from: $1"
    rm -rf "$TEMPDIR"
    die "Aborting due to download failure"
}

download() {
    if command -v curl > /dev/null 2>&1; then
        curl --connect-timeout 10 -s "$1" > "$2" || download_fail "$1"
    else
        busybox wget -T 10 --no-check-certificate -qO "$2" "$1" || download_fail "$1"
    fi
}

VERSIONS_HTML="PIXEL_VERSIONS_HTML"
LATEST_HTML="PIXEL_LATEST_HTML"
BETA_HTML="PIXEL_BETA_HTML"
OTA_HTML="PIXEL_OTA_HTML"
METADATA_FILE="PIXEL_ZIP_METADATA"

download https://developer.android.com/about/versions "$VERSIONS_HTML"

BETA_URL=$(grep -o 'https://developer.android.com/about/versions/.*[0-9]"' "$VERSIONS_HTML" | sort -ru | cut -d" -f1 | head -n1)
download "$BETA_URL" "$LATEST_HTML"

if grep -qE 'Developer Preview|tooltip>.*preview program' "$LATEST_HTML"; then
    BETA_URL=$(grep -o 'https://developer.android.com/about/versions/.*[0-9]"' "$VERSIONS_HTML" | sort -ru | cut -d" -f1 | head -n2 | tail -n1)
    download "$BETA_URL" "$BETA_HTML"
else
    mv "$LATEST_HTML" "$BETA_HTML"
fi

OTA_LINK="https://developer.android.com$(grep -o 'href=".*download-ota.*"' "$BETA_HTML" | cut -d" -f2 | head -n1)"
download "$OTA_LINK" "$OTA_HTML"

MODEL_LIST=$(grep -A1 'tr id=' "$OTA_HTML" | grep 'td' | sed 's;.*<td>\(.*\)</td>;\1;')
PRODUCT_LIST=$(grep -o 'ota/.*_beta' "$OTA_HTML" | cut -d/ -f2)
OTA_LIST=$(grep 'ota/.*_beta' "$OTA_HTML" | cut -d" -f2)

if [ "$(echo "$MODEL_LIST" | wc -l)" -ne "$(echo "$PRODUCT_LIST" | wc -l)" ]; then
    die "Mismatch in model and product list count"
fi

rand=$((RANDOM % $(echo "$MODEL_LIST" | wc -l)))
MODEL=$(echo "$MODEL_LIST" | sed -n "$((rand + 1))p")
PRODUCT=$(echo "$PRODUCT_LIST" | sed -n "$((rand + 1))p")
OTA=$(echo "$OTA_LIST" | grep "$PRODUCT")

echo "[+] Selected: $MODEL ($PRODUCT)"

(ulimit -f 2; download "https://dl.google.com/$OTA" "$METADATA_FILE") || download_fail "https://dl.google.com/$OTA"

FINGERPRINT=$(strings "$METADATA_FILE" | grep -am1 'post-build=' | cut -d= -f2)
SECURITY_PATCH=$(strings "$METADATA_FILE" | grep -am1 'security-patch-level=' | cut -d= -f2)

[ -z "$FINGERPRINT" ] || [ -z "$SECURITY_PATCH" ] && die "Missing fingerprint or security patch"

for config in spoofProvider spoofProps spoofSignature DEBUG spoofVendingSdk; do
    if grep -q ""$config": true" "$MODDIR/pif.json" 2>/dev/null; then
        eval "$config=true"
    else
        eval "$config=false"
    fi
done

cat <<EOF > pif.json
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
echo "[+] pif.json updated at /data/adb/pif.json"

TS_PATCH=/data/adb/tricky_store/security_patch.txt
if [ -d "/data/adb/tricky_store" ]; then
    [ ! -f "$TS_PATCH" ] && echo "all=" > "$TS_PATCH"
    if grep -q "all=" "$TS_PATCH"; then
        sed -i "s/all=.*/all=$SECURITY_PATCH/" "$TS_PATCH"
    fi
    if grep -q "system=" "$TS_PATCH"; then
        sed -i "s/system=.*/system=$(echo ${SECURITY_PATCH//-} | cut -c1-6)/" "$TS_PATCH"
    fi
    echo "[+] Updated Tricky Store security_patch.txt"
fi

for PID in $(busybox pidof com.google.android.gms.unstable 2>/dev/null); do
    echo "[+] Killing GMS PID $PID"
    kill -9 "$PID"
done

echo "[✔] Done."
rm -rf "$TEMPDIR"
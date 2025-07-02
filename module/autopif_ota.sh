#!/bin/sh

PATH=/data/adb/ap/bin:/data/adb/ksu/bin:/data/adb/magisk:/data/data/com.termux/files/usr/bin:$PATH
MODDIR=/data/adb/modules/playintegrityfix

. $MODDIR/common_func.sh

# lets try to use tmpfs for processing
TEMPDIR="$MODDIR/temp" #fallback
[ -w /sbin ] && TEMPDIR="/sbin/playintegrityfix"
[ -w /debug_ramdisk ] && TEMPDIR="/debug_ramdisk/playintegrityfix"
[ -w /dev ] && TEMPDIR="/dev/playintegrityfix"
mkdir -p "$TEMPDIR"

# fetch script
if download "https://raw.githubusercontent.com/KOWX712/PlayIntegrityFix/inject_s/module/autopif.sh" "$TEMPDIR/temp_autopif.sh"; then
    # hash
    curhash="$(cat $MODDIR/autopif.sh | busybox crc32)"
    newhash="$(cat $TEMPDIR/temp_autopif.sh | busybox crc32)"

    if [ -s "$TEMPDIR/temp_autopif.sh" ] && [ ! "$newhash" = "$curhash" ]; then
        cat "$TEMPDIR/temp_autopif.sh" > "$MODDIR/autopif.sh"
        echo "[+] autopif has been updated"
    fi
else
    echo "[!] OTA failed, skipping update."
fi

rm -rf "$TEMPDIR"

# EOF

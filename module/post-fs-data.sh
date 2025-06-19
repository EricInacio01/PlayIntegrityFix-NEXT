#!/system/bin/sh

MODPATH="${0%/*}"
. "$MODPATH/common_func.sh"

# Magisk DenyList
if magisk --denylist status; then
    magisk --denylist rm com.google.android.gms
else
    if [ -d "/data/adb/modules/zygisk_shamiko" ] && [ ! -f "/data/adb/shamiko/whitelist" ]; then
        magisk --denylist add com.google.android.gms
        magisk --denylist add com.google.android.gms.unstable
        magisk --denylist add com.android.vending
    fi
fi

# Samsung
resetprop_if_diff ro.boot.warranty_bit 0
resetprop_if_diff ro.vendor.boot.warranty_bit 0
resetprop_if_diff ro.vendor.warranty_bit 0
resetprop_if_diff ro.warranty_bit 0

# Realme
resetprop_if_diff ro.boot.realmebootstate green

# OnePlus
resetprop_if_diff ro.is_ever_orange 0

# PixelProject
resetprop --delete persist.sys.pihooks.first_api_level

# Fix “ro.*.build.tags” to “release-keys”
for PROP in $(resetprop | grep -oE 'ro\..*\.build\.tags'); do
    resetprop_if_diff "$PROP" release-keys
done

# Change “ro.*.build.type” to “user”
for PROP in $(resetprop | grep -oE 'ro\..*\.build\.type'); do
    resetprop_if_diff "$PROP" user
done

# Common security properties
resetprop_if_diff ro.adb.secure 1
resetprop_if_diff ro.debuggable 0
resetprop_if_diff ro.force.debuggable 0
resetprop_if_diff ro.secure 1

# Fixes conflict with AOSPA PIHooks when persist props do not exist
if [ -n "$(resetprop ro.aospa.version)" ]; then
    for PROP in persist.sys.pihooks.first_api_level persist.sys.pihooks.security_patch; do
        resetprop | grep -q "\[$PROP\]" || resetprop -n -p "$PROP" ""
    done
fi

# Fixes conflict with spoofing in PixelPropsUtils (when spoofProvider is disabled)
if [ -n "$(resetprop persist.sys.pixelprops.pi)" ]; then
    resetprop -n -p persist.sys.pixelprops.pi false
    resetprop -n -p persist.sys.pixelprops.gapps false
    resetprop -n -p persist.sys.pixelprops.gms false
fi

# Fixes automatic spoofing of LeafOS for GMS (LeafOS framework patch)
if [ -f /data/system/gms_certified_props.json ] && [ "$(resetprop persist.sys.spoof.gms)" != "false" ]; then
    resetprop persist.sys.spoof.gms false
fi

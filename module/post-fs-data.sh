MODPATH="${0%/*}"
. "$MODPATH"/common_func.sh

# Remove Play Services and Play Store from Magisk DenyList when set to Enforce in normal mode
if magisk --denylist status; then
    magisk --denylist rm com.google.android.gms
else
    # Check if Shamiko is installed and whitelist feature isn't enabled
    if [ -d "/data/adb/modules/zygisk_shamiko" ] && [ ! -f "/data/adb/shamiko/whitelist" ]; then
        magisk --denylist add com.google.android.gms com.google.android.gms
        magisk --denylist add com.google.android.gms com.google.android.gms.unstable
        magisk --denylist add com.android.vending
    fi
fi

# Hide action.sh if not using Magisk
if [ "$KSU" = true ] || [ "$APATCH" = true ]; then
    [ -f "$MODPATH/action.sh" ] && mv -f "$MODPATH/action.sh" "$MODPATH/action.sh.old"
else
    [ -f "$MODPATH/action.sh.old" ] && mv -f "$MODPATH/action.sh.old" "$MODPATH/action.sh"
fi

# Conditional early sensitive properties

# Samsung
resetprop_if_diff ro.boot.warranty_bit 0
resetprop_if_diff ro.vendor.boot.warranty_bit 0
resetprop_if_diff ro.vendor.warranty_bit 0
resetprop_if_diff ro.warranty_bit 0

# Realme
resetprop_if_diff ro.boot.realmebootstate green

# OnePlus
resetprop_if_diff ro.is_ever_orange 0

# Microsoft
for PROP in $(resetprop | grep -oE 'ro.*.build.tags'); do
    resetprop_if_diff "$PROP" release-keys
done

# Other
for PROP in $(resetprop | grep -oE 'ro.*.build.type'); do
    resetprop_if_diff "$PROP" user
done
resetprop_if_diff ro.adb.secure 1
resetprop_if_diff ro.debuggable 0
resetprop_if_diff ro.force.debuggable 0
resetprop_if_diff ro.secure 1

# Work around custom ROM PropImitationHooks conflict when their persist props don't exist
if [ -n "$(resetprop ro.aospa.version)" -o -n "$(resetprop net.pixelos.version)" -o -n "$(resetprop ro.afterlife.version)" -o -f /data/system/gms_certified_props.json ]; then
    for PROP in persist.sys.pihooks.first_api_level persist.sys.pihooks.security_patch; do
        resetprop | grep -q "\[$PROP\]" || persistprop "$PROP" ""
    done
fi

# Work around supported custom ROM PropImitationHooks/PixelPropsUtils (and hybrids) conflict when spoofProvider is disabled
if resetprop | grep -qE "persist.sys.pihooks|persist.sys.entryhooks|persist.sys.pixelprops" || [ -f /data/system/gms_certified_props.json ]; then
    persistprop persist.sys.pihooks.disable.gms_props true
    persistprop persist.sys.pihooks.disable.gms_key_attestation_block true
    persistprop persist.sys.entryhooks_enabled false
    persistprop persist.sys.pixelprops.gms false
    persistprop persist.sys.pixelprops.gapps false
    persistprop persist.sys.pixelprops.google false
    persistprop persist.sys.pixelprops.pi false
fi

# LeafOS "gmscompat: Dynamically spoof props for GMS"
# https://review.leafos.org/c/LeafOS-Project/android_frameworks_base/+/4416
# https://review.leafos.org/c/LeafOS-Project/android_frameworks_base/+/4417/5
if [ -f /data/system/gms_certified_props.json ] && [ ! "$(resetprop persist.sys.spoof.gms)" = "false" ]; then
	resetprop persist.sys.spoof.gms false
fi

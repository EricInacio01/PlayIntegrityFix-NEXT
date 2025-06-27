#!/system/bin/sh

# ===============================
# PIF-Next, an fork of chiteroman's module.
# Thanks for Chiteroman for the original module.
# Thanks for osm0sis for supporting autopif2.sh scripts in your Fork.
# Thanks for Papacuz for security_patch scripts.
# ===============================

if ! $BOOTMODE; then
    ui_print "================================================="
    ui_print "! ERROR: Installation from recovery NOT supported"
    ui_print "! Please use Magisk / KernelSU / APatch app"
    ui_print "================================================="
    abort
fi

# android < 8 not supported
[ "$API" -lt 26 ] && abort "❌ Android < 8.0 is not supported!"

# Android 14+ warning
if [ "$API" -ge 34 ]; then
    ui_print "----------------------------------------"
    ui_print "  🌐 Android 14 or higher detected"
    ui_print "  ⚠ This module comes with spoofvendingsdk DISABLED by default."
    ui_print "    Enabling it may cause crashes in the Play Store."
    ui_print "----------------------------------------"
fi

check_zygisk() {
    local MAGISK_DIR="/data/adb/magisk"
    local MSG=" ❌ Zygisk is not enabled.\n- Enable Zygisk in Magisk settings\n- Install ZygiskNext or ReZygisk module"

    [ -d /data/adb/modules/zygisksu ] || [ -d /data/adb/modules/rezygisk ] && return 0

    if [ -d "$MAGISK_DIR" ]; then
        local zygisk_status
        zygisk_status=$(magisk --sqlite "SELECT value FROM settings WHERE key='zygisk';")
        [ "$zygisk_status" = "value=1" ] || abort "$MSG"
    else
        abort "$MSG"
    fi
}

check_zygisk

[ -d /data/adb/modules/safetynet-fix ] && {
    ui_print "⚠ safetynet-fix is incompatible and will be removed on next reboot."
    touch /data/adb/modules/safetynet-fix/remove
}
[ -d /data/adb/modules/playcurl ] && ui_print "⚠ playcurl may overwrite the fingerprint with invalid data."
[ -d /data/adb/modules/MagiskHidePropsConf ] && ui_print "⚠ MagiskHidePropsConf may cause issues with PIF."

##########
# Better TrickyStore detection...
ui_print "----------------------------------------"
ui_print "  🔍 Detecting Tricky Store..."
TRICKYSTORE_PATH="/data/adb/modules/tricky_store"
[ ! -d "$TRICKYSTORE_PATH" ] && abort "❌ Tricky Store not detected!\nInstall it first."
ui_print "  ✅ Tricky Store detected."

# Avoid duplicates in target.txt
TARGET_USER_PATH="/data/adb/tricky_store/target.txt"
TARGET_MODULE_PATH="$MODPATH/target.txt"
if [ -f "$TARGET_USER_PATH" ]; then
    ui_print "  🔁 Merging target.txt..."
    ui_print "----------------------------------------"
    cat "$TARGET_USER_PATH" "$TARGET_MODULE_PATH" | sort -u > "$TARGET_USER_PATH.tmp"
    mv -f "$TARGET_USER_PATH.tmp" "$TARGET_USER_PATH"
else
    cp -f "$TARGET_MODULE_PATH" "$TARGET_USER_PATH"
fi

# Better Keybox mechanism, avoid to overwrite keybox.xml settings
KEYBOX_USER_PATH="/data/adb/tricky_store/keybox.xml"
KEYBOX_MODULE_PATH="$MODPATH/keybox.xml"
if [ -f "$KEYBOX_USER_PATH" ] && ! cmp -s "$KEYBOX_USER_PATH" "$KEYBOX_MODULE_PATH"; then
    ui_print "  ❓ Existing keybox.xml detected"
    ui_print "  Do you want to overwrite it?"
    ui_print "  - Volume Up: Yes"
    ui_print "  - Volume Down: No"
    ui_print "----------------------------------------"
    while true; do
        key=$(getevent -lc 1 2>/dev/null | grep -E 'KEY_VOLUME(UP|DOWN)')
        echo "$key" | grep -q "KEY_VOLUMEUP" && { cp -f "$KEYBOX_MODULE_PATH" "$KEYBOX_USER_PATH"; break; }
        echo "$key" | grep -q "KEY_VOLUMEDOWN" && { ui_print "🚫 keybox.xml preserved."; break; }
        sleep 0.1
    done
else
    cp -f "$KEYBOX_MODULE_PATH" "$KEYBOX_USER_PATH"
fi

# Copy security_patch
cp -f "$MODPATH/security_patch.txt" /data/adb/tricky_store/

# Improved TrickyStore mechanism
OLD_JSON="/data/adb/modules/playintegrityfix/pif.json"
NEW_JSON="$MODPATH/pif.json"

ui_print "  📦 Preserving previous settings..."
for key in spoofProvider spoofProps spoofSignature DEBUG spoofVendingSdk; do
    grep -q "$key" "$OLD_JSON" || continue
    if grep -q "\"$key\": true" "$OLD_JSON"; then
        sed -i "s/\"$key\": .*/\"$key\": true,/" "$NEW_JSON"
    else
        sed -i "s/\"$key\": .*/\"$key\": false,/" "$NEW_JSON"
    fi
done
sed -i ':a;N;$!ba;s/\,\n\}/\n\}/g' "$NEW_JSON"

# Restore customized pif.json
[ -f /data/adb/pif.json ] && mv -f /data/adb/pif.json /data/adb/pif.json.old && ui_print "  📂 Backup pif.json preserved."

# Final settings
chmod +x "$MODPATH/action.sh"
ui_print "----------------------------------------"
ui_print "  ✅ Settings applied successfully."
ui_print "----------------------------------------"
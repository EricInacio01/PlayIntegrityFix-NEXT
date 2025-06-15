# Don't flash in recovery!
if ! $BOOTMODE; then
    ui_print "================================================="
    ui_print "! ERROR: Installation from recovery NOT supported"
    ui_print "! Please use Magisk / KernelSU / APatch app"
    ui_print "================================================="
    abort
fi

# Error on < Android 8
if [ "$API" -lt 26 ]; then
    abort "❌ Android < 8.0 is not supported!"
fi

if [ "$API" -eq 34 ] || [ "$API" -eq 35 ] || [ "$API" -eq 36 ]; then
    ui_print "----------------------------------------"
    ui_print "  🌐 Android 14 or higher detected"
    ui_print "  ⚠ SpoofVendingSdk is enabled by default"
    ui_print "    (May cause Play Store issues)"
    ui_print "  " 
    ui_print "  ❓ Apply SpoofVendingSdk?"
    ui_print "  - Volume Up: Accept (Keep enabled)"
    ui_print "  - Volume Down: Decline (Disable)"
    ui_print "----------------------------------------"
    
    while true; do
        key=$(getevent -lc 1 2>/dev/null | grep -E 'KEY_VOLUME(UP|DOWN)')
        if echo "$key" | grep -q "KEY_VOLUMEUP"; then
            ui_print "  ✅ SpoofVendingSdk will remain enabled"
            break
        elif echo "$key" | grep -q "KEY_VOLUMEDOWN"; then
            ui_print "  ✅ SpoofVendingSdk will be disabled"
            sed -i 's/"spoofVendingSdk": true/"spoofVendingSdk": false/' "$MODPATH/pif.json"
            break
        fi
        sleep 0.1
    done
fi

check_zygisk() {
    local ZYGISK_MODULE="/data/adb/modules/zygisksu"
    local REZYGISK_MODULE="/data/adb/modules/rezygisk"
    local MAGISK_DIR="/data/adb/magisk"
    local ZYGISK_MSG="❌ Zygisk is not enabled. Please:
    - Enable Zygisk in Magisk settings
    - Install ZygiskNext or ReZygisk module"

    if [ -d "$ZYGISK_MODULE" ] || [ -d "$REZYGISK_MODULE" ]; then
        return 0
    fi

    if [ -d "$MAGISK_DIR" ]; then
        local ZYGISK_STATUS
        ZYGISK_STATUS=$(magisk --sqlite "SELECT value FROM settings WHERE key='zygisk';")
        if [ "$ZYGISK_STATUS" = "value=0" ]; then
            abort "$ZYGISK_MSG"
        fi
    else
        abort "$ZYGISK_MSG"
    fi
}

# Require Zygisk
check_zygisk

# Check for incompatible modules
SNFix="/data/adb/modules/safetynet-fix"
if [ -d "$SNFix" ]; then
    ui_print "⚠ safetynet-fix is obsolete and incompatible with PIF"
    ui_print "  Will be removed on next reboot. Avoid reinstalling!"
    touch "$SNFix"/remove
fi

if [ -d "/data/adb/modules/playcurl" ]; then
    ui_print "⚠ playcurl may overwrite fingerprint with invalid data!"
fi

if [ -d "/data/adb/modules/MagiskHidePropsConf" ]; then
    ui_print "⚠ MagiskHidePropsConf may cause issues with PIF"
fi

# TS detection
ui_print "----------------------------------------"
ui_print "  🔍 Detecting Tricky Store..."
TRICKYSTORE_PATH="/data/adb/modules/tricky_store/"
if [ ! -d "$TRICKYSTORE_PATH" ]; then
    ui_print "  ❌ Tricky Store not detected!"
    ui_print "  This module requires Tricky Store to work."
    abort "  Installation cancelled. Install Tricky Store first."
fi
ui_print "  ✅ TrickyStore detected!"

# Preserve previous settings
spoofConfig="spoofProvider spoofProps spoofSignature DEBUG spoofVendingSdk"
for config in $spoofConfig; do
    grep -q "$config" "/data/adb/modules/playintegrityfix/pif.json" || continue
    if grep -q "\"$config\": true" "/data/adb/modules/playintegrityfix/pif.json"; then
        sed -i "s/\"$config\": .*/\"$config\": true,/" "$MODPATH/pif.json"
    else
        sed -i "s/\"$config\": .*/\"$config\": false,/" "$MODPATH/pif.json"
    fi
done
sed -i ':a;N;$!ba;s/,\n}/\n}/g' "$MODPATH/pif.json"

# Restore custom fingerprint
if [ -f "/data/adb/pif.json" ]; then
    ui_print "- 📂 Backup pif.json restored."
    mv -f /data/adb/pif.json /data/adb/pif.json.old
fi

# Set execute permissions
chmod +x "$MODPATH/action.sh"

# Apply tricky Store settings (when done, btw) 
ui_print "----------------------------------------"
ui_print "  🔧 Applying new verdicts..."
cp -f "$MODPATH/keybox.xml" /data/adb/tricky_store/
cp -f "$MODPATH/target.txt" /data/adb/tricky_store/
cp -f "$MODPATH/security_patch.txt" /data/adb/tricky_store/
sleep 1.3
ui_print "  ✅ Done!"
ui_print "----------------------------------------"
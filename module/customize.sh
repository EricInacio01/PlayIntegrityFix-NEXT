#!/system/bin/sh

# abort recovery installation
if ! $BOOTMODE; then
    ui_print "================================================="
    ui_print "! ERROR: Installation from recovery NOT supported"
    ui_print "! Please use Magisk / KernelSU / APatch app"
    ui_print "================================================="
    abort
fi

if [ "$API" -lt 26 ]; then
    abort "❌ Android < 8.0 is not supported!"
fi


# Detect Android 14+ and optionally disable SpoofVendingSdk
if [ "$API" -ge 34 ]; then
    ui_print "----------------------------------------"
    ui_print "  🌐 Android 14 or higher detected"
    ui_print "  ⚠ SpoofVendingSdk is enabled by default"
    ui_print "    (May cause Play Store issues)"
    ui_print ""
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


# Check if Zygisk is enabled
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
        [ "$ZYGISK_STATUS" = "value=1" ] || abort "$ZYGISK_MSG"
    else
        abort "$ZYGISK_MSG"
    fi
}

check_zygisk

# abort obsolete modules
if [ -d "/data/adb/modules/safetynet-fix" ]; then
    ui_print "⚠ safetynet-fix is obsolete and incompatible with PIF"
    ui_print "  Will be removed on next reboot. Avoid reinstalling!"
    touch "/data/adb/modules/safetynet-fix/remove"
fi

[ -d "/data/adb/modules/playcurl" ] &&     ui_print "⚠ playcurl may overwrite fingerprint with invalid data!"

[ -d "/data/adb/modules/MagiskHidePropsConf" ] &&     ui_print "⚠ MagiskHidePropsConf may cause issues with PIF"

# ────────────────────────────────────────────────
# 🔍 Tricky Store Detection
# ────────────────────────────────────────────────
ui_print "----------------------------------------"
ui_print "  🔍 Detecting Tricky Store..."
TRICKYSTORE_PATH="/data/adb/modules/tricky_store"
if [ ! -d "$TRICKYSTORE_PATH" ]; then
    ui_print "  ❌ Tricky Store not detected!"
    abort "  Installation cancelled. Install Tricky Store first."
fi
ui_print "  ✅ Tricky Store detected!"


# preserve previous spoof settings
spoofConfig="spoofProvider spoofProps spoofSignature DEBUG spoofVendingSdk"
for config in $spoofConfig; do
    grep -q "$config" "/data/adb/modules/playintegrityfix/pif.json" || continue
    if grep -q ""$config": true" "/data/adb/modules/playintegrityfix/pif.json"; then
        sed -i "s/"$config": .*/"$config": true,/" "$MODPATH/pif.json"
    else
        sed -i "s/"$config": .*/"$config": false,/" "$MODPATH/pif.json"
    fi
done
sed -i ':a;N;$!ba;s/,
}/
}/g' "$MODPATH/pif.json"

# fingerprint restore
if [ -f "/data/adb/pif.json" ]; then
    ui_print "- 📂 Backup pif.json restored."
    mv -f /data/adb/pif.json /data/adb/pif.json.old
fi

# TrickyStore detection
ui_print "----------------------------------------"
ui_print "  🔧 Applying new verdicts..."

# keybox.xml: Ask if you want to replace
KEYBOX_TARGET="/data/adb/tricky_store/keybox.xml"
if [ -f "$KEYBOX_TARGET" ]; then
    ui_print "❓ An existing keybox.xml file was detected."
    ui_print "  Would you like to replace it with the module version?"
    ui_print "  - Volume Up: Yes"
    ui_print "  - Volume Down: No"
    while true; do
        key=$(getevent -lc 1 2>/dev/null | grep -E 'KEY_VOLUME(UP|DOWN)')
        if echo "$key" | grep -q "KEY_VOLUMEUP"; then
            cp -f "$MODPATH/keybox.xml" "$KEYBOX_TARGET"
            ui_print "  ✅ keybox.xml replaced."
            break
        elif echo "$key" | grep -q "KEY_VOLUMEDOWN"; then
            ui_print "  ❎ keybox.xml preserved."
            break
        fi
        sleep 0.1
    done
else
    cp -f "$MODPATH/keybox.xml" "$KEYBOX_TARGET"
fi

# Apply new target.txt merging
TARGET_TXT="/data/adb/tricky_store/target.txt"
if [ -f "$TARGET_TXT" ]; then
    ui_print "  ➕ Merging target.txt with existing configuration..."
    grep -vxFf "$MODPATH/target.txt" "$TARGET_TXT" >> "$MODPATH/target.txt"
fi
cp -f "$MODPATH/target.txt" "$TARGET_TXT"
cp -f "$MODPATH/security_patch.txt" /data/adb/tricky_store/

sleep 1.3
ui_print "  "
ui_print "  ✅ Settings successfully applied! REBOOT your device."
ui_print "----------------------------------------"

# CANNOT Install in recovery!
chmod +x "$MODPATH/action.sh"
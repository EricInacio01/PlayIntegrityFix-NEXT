MODDIR="/data/adb/modules/playintegrityfix"

if [ -z "$MMRL" ] && [ ! -z "$MAGISKTMP" ]; then
    pm path io.github.a13e300.ksuwebui > /dev/null 2>&1 && {
        echo "- Launching WebUI in KSUWebUIStandalone..."
        am start -n "io.github.a13e300.ksuwebui/.WebUIActivity" -e id "playintegrityfix"
        exit 0
    }
    pm path com.dergoogler.mmrl.wx > /dev/null 2>&1 && {
        echo "- Launching WebUI in WebUI X..."
        am start -n "com.dergoogler.mmrl.wx/.ui.activity.webui.WebUIActivity" -e MOD_ID "playintegrityfix"
        exit 0
    }
fi

sh $MODDIR/autopif_ota.sh || true
sh $MODDIR/autopif.sh

#!/system/bin/sh

# Diretório base do módulo
MODPATH="${0%/*}"
. "$MODPATH/common_func.sh"

# Update Security Patch
new_patch="2025-06-05"
resetprop -n ro.build.version.security_patch "$new_patch"
resetprop -n ro.vendor.build.security_patch "$new_patch"

# ----------------------------------------------

# add for some recovery fuunctions
resetprop_if_match ro.boot.mode recovery unknown
resetprop_if_match ro.bootmode recovery unknown
resetprop_if_match vendor.boot.mode recovery unknown

#SELinux=enforcing
resetprop_if_diff ro.boot.selinux enforcing

# anti-detection in selinux stats
if [ "$(toybox cat /sys/fs/selinux/enforce)" = "0" ]; then
    chmod 640 /sys/fs/selinux/enforce
    chmod 440 /sys/fs/selinux/policy
fi

until [ "$(getprop sys.boot_completed)" = "1" ]; do
    sleep 1
done

# ----------------------------------------------
# PlayIntegrityFix + OEM
# Avoid bootloop on some Xiaomi devices
resetprop_if_diff ro.secureboot.lockstate locked

resetprop_if_diff ro.boot.flash.locked 1
resetprop_if_diff ro.boot.realme.lockstate 1

resetprop_if_diff ro.boot.vbmeta.device_state locked
resetprop_if_diff vendor.boot.verifiedbootstate green

resetprop_if_diff ro.boot.verifiedbootstate green
resetprop_if_diff ro.boot.veritymode enforcing
resetprop_if_diff vendor.boot.vbmeta.device_state locked

resetprop_if_diff sys.oem_unlock_allowed 0

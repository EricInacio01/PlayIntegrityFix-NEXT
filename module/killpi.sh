#!/system/bin/sh
# killpi.sh by osm0sis @ xda-developers
# Kill the Google Play services DroidGuard and Play Store processes
# (com.google.android.gms.unstable and com.android.vending)

if [ "$USER" != "root" -a "$(whoami 2>/dev/null)" != "root" ]; then
  echo "killpi: need root permissions";
  exit 1;
fi;

killall com.google.android.gms.unstable;
killall com.android.vending;

sleep 1
if pgrep com.google.android.gms.unstable; then
  echo "Forcibly killing com.google.android.gms.unstable"
  pkill -9 com.google.android.gms.unstable
fi

if pgrep com.android.vending; then
  echo "Forcibly killing com.android.vending"
  pkill -9 com.android.vending
fi
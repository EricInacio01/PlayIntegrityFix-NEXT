
# 🚀 PlayIntegrityFix NEXT
*This is a fork of PlayIntegrityFix, created by chiteroman. The aim of this module is to help the user, in an automatic way, to ensure the greatest possible number of valid attestations under the new rules of the PlayIntegrity API.*

> ⚠️ For this module to work as it should, you'll need to install TrickyStore beforehand (links are below this readme)

[![GitHub release (latest by date)](https://img.shields.io/github/v/release/EricInacio01/PlayIntegrityFix-NEXT?label=Release&color=blue&style=flat)](https://github.com/EricInacio01/PlayIntegrityFix-NEXT/releases/latest)
[![GitHub Release Date](https://img.shields.io/github/release-date/EricInacio01/PlayIntegrityFix-NEXT?label=Release%20Date&color=brightgreen&style=flat)](https://github.com/EricInacio01/PlayIntegrityFix-NEXT/releases)
[![GitHub Releases](https://img.shields.io/github/downloads/EricInacio01/PlayIntegrityFix-NEXT/latest/total?label=Downloads%20%28Latest%20Release%29&color=blue&style=flat)](https://github.com/EricInacio01/PlayIntegrityFix-NEXT/releases/latest)
[![GitHub All Releases](https://img.shields.io/github/downloads/EricInacio01/PlayIntegrityFix-NEXT/total?label=Total%20Downloads%20%28All%20Releases%29&color=brightgreen&style=flat)](https://github.com/EricInacio01/PlayIntegrityFix-NEXT/releases)


---

## ⚠️ NOTES
The purpose of this module is to ensure as much validation as possible on your device. On some devices running Android 14 or higher, activating SpoofVendingSDK may cause crashes in Play Store Services. To fix this problem, follow the steps below:

1. Access the module's WebUI and disable the “Spoof sdk version to Play Store” option.

> If you are running a custom ROM or kernel, make sure that your kernel name is not blacklisted. You can check this by running the command uname -r. You can find the list of prohibited strings here: https://xdaforums.com/t/module-play-integrity-fix-safetynet-fix.4607985/post-89308909

## 💡 Tips and Tricks
There are a few tips you can use with this Fork:

- [TrickyStore](https://github.com/5ec1cff/TrickyStore) - You can use it to secure better certificates (e.g. security patch, and a beeebox, if you know what I mean).
- [TrickyAddon](https://github.com/KOWX712/Tricky-Addon-Update-Target-List) - An excellent Front-End for TrickyStore, useful for security patching, configuring boot hash and also target.txt

## 🗃️ How to Install
PIF Next only works with ONE of the solutions below:
- [Magisk](https://github.com/topjohnwu/Magisk) with Zygisk enabled.
- [KernelSU](https://github.com/tiann/KernelSU) with [ZygiskNext](https://github.com/Dr-TSNG/ZygiskNext) or [ReZygisk](https://github.com/PerformanC/ReZygisk) module installed.
- [KernelSU Next](https://github.com/KernelSU-Next/KernelSU-Next) with [ZygiskNext](https://github.com/Dr-TSNG/ZygiskNext) or [ReZygisk](https://github.com/PerformanC/ReZygisk) module installed.
- [APatch](https://github.com/bmax121/APatch) with [ZygiskNext](https://github.com/Dr-TSNG/ZygiskNext) or [ReZygisk](https://github.com/PerformanC/ReZygisk) module installed.

## ✅ How to Check Veredicts
After flashing PIF Next, you can check your verdicts using:
- [Play Integrity API Checker (PlayStore)](https://play.google.com/store/apps/details?id=gr.nikolasspyr.integritycheck&pli=1)
*or by enabling Developer Options in the Play Store by going to **Settings** > **About **> Click 5x on **“Play Store Version”**, then go to **‘General’** >** “Developer Options” **and click on **“Check Integrity”**.*

NOTICE: If you encounter a limit error message, try using a different app. This issue occurs due to high demand for attestation requests from many users.

---
After requesting an attestation, expect the following outcomes:

    Basic Integrity: ✅ Passed
    Device Integrity: ✅ Passed
    Strong Integrity: ✅ Passed (under certain conditions).
    Virtual Integrity: ❌ Not Passed (applies only to emulators)

Learn more about these verdicts in this post: https://xdaforums.com/t/info-play-integrity-api-replacement-for-safetynet.4479337/

> It's worth remembering that for some devices, certification may be easier or more difficult to carry out. So bear in mind that PIF-Next is not responsible for certification failures, so it is recommended that the user follows all the recommendations in this module.

## chiteroman tribute's
Be happy not because the original project is over, but because it happened. A living form of community resistance and as a developer to bring the best possible to rooted users. Many complain, few do, but we thank Marcos (chiteroman) for his efforts and the remnants of a dev who is very good at what he does. Thank you Marcos for your contribution to the Android community.

## Acknowledgments
- [PlayIntegrityFIX (Site is down)](https://github.com/chiteroman/PlayIntegrityFix) by [chiteroman](https://github.com/chiteroman) author of original PIF module.
- [kdrag0n](https://github.com/kdrag0n/safetynet-fix) & [Displax](https://github.com/Displax/safetynet-fix) for the original idea.
- [osm0sis](https://github.com/osm0sis) for his original [autopif2.sh](https://github.com/osm0sis/PlayIntegrityFork/blob/main/module/autopif2.sh) script, and [backslashxx](https://github.com/backslashxx) & [KOWX712](https://github.com/KOWX712) for improving it ([action.sh](https://github.com/chiteroman/PlayIntegrityFix/blob/main/module/action.sh)).
- [Update Security Patch](https://github.com/Doze-off/update_security_patch) by Papacuz
- [TrickyStore](https://github.com/5ec1cff/TrickyStore) by 5ec1cff
- [PlayIntegrityFix (Fork)](https://github.com/KOWX712/PlayIntegrityFix) by KOW

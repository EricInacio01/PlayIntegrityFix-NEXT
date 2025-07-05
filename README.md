

# 🚀 PlayIntegrityFix NEXT
*PlayIntegrityFix Fork, by chiteroman. This module is a certification assistant designed to ensure valid attestation in compliance with the new PlayIntegrity rules.*


[![GitHub release (latest by date)](https://img.shields.io/github/v/release/EricInacio01/PlayIntegrityFix-NEXT?label=Release&color=blue&style=flat)](https://github.com/EricInacio01/PlayIntegrityFix-NEXT/releases/latest)
[![GitHub Release Date](https://img.shields.io/github/release-date/EricInacio01/PlayIntegrityFix-NEXT?label=Release%20Date&color=brightgreen&style=flat)](https://github.com/EricInacio01/PlayIntegrityFix-NEXT/releases)
[![GitHub Releases](https://img.shields.io/github/downloads/EricInacio01/PlayIntegrityFix-NEXT/latest/total?label=Downloads%20%28Latest%20Release%29&color=blue&style=flat)](https://github.com/EricInacio01/PlayIntegrityFix-NEXT/releases/latest)
[![GitHub All Releases](https://img.shields.io/github/downloads/EricInacio01/PlayIntegrityFix-NEXT/total?label=Total%20Downloads%20%28All%20Releases%29&color=brightgreen&style=flat)](https://github.com/EricInacio01/PlayIntegrityFix-NEXT/releases)


---

## ⚠️ NOTES
The purpose of this module is not to hide root access or mask detections in other applications. It simply includes a customized `target.txt` file with a selection of pre-defined applications integrated with TrickyStore during installation.

## 🗃️ How to Install
PIF-Next only works with ONE of the solutions below:
- [Magisk](https://github.com/topjohnwu/Magisk) with Zygisk enabled.
- [KernelSU](https://github.com/tiann/KernelSU) with [ZygiskNext](https://github.com/Dr-TSNG/ZygiskNext) or [ReZygisk](https://github.com/PerformanC/ReZygisk) module installed.
- [KernelSU Next](https://github.com/KernelSU-Next/KernelSU-Next) with [ZygiskNext](https://github.com/Dr-TSNG/ZygiskNext) or [ReZygisk](https://github.com/PerformanC/ReZygisk) module installed.
- [APatch](https://github.com/bmax121/APatch) with [ZygiskNext](https://github.com/Dr-TSNG/ZygiskNext) or [ReZygisk](https://github.com/PerformanC/ReZygisk) module installed.

## 💡 Tips and Tricks
Here are some optional modules you can use to enhance your experience:

- [Tricky-Addon-Update-Target-List](https://github.com/KOWX712/Tricky-Addon-Update-Target-List) - by [KOW](https://github.com/KOWX712)
- [Hide Folders](https://github.com/Doze-off/Hide-folders-files) - by [Doze-off](https://github.com/Doze-off/Hide-folders-files)

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

## Acknowledgments
- [kdrag0n](https://github.com/kdrag0n/safetynet-fix) & [Displax](https://github.com/Displax/safetynet-fix) for the original idea.
- [PlayIntegrityFix (Fork)](https://github.com/KOWX712/PlayIntegrityFix) by KOW
- [osm0sis](https://github.com/osm0sis) for his original [autopif2.sh](https://github.com/osm0sis/PlayIntegrityFork/blob/main/module/autopif2.sh) script, and [backslashxx](https://github.com/backslashxx) & [KOWX712](https://github.com/KOWX712) for improving it ([action.sh](https://github.com/chiteroman/PlayIntegrityFix/blob/main/module/action.sh)).
- [Update Security Patch](https://github.com/Doze-off/update_security_patch) by Papacuz
- [TrickyStore](https://github.com/5ec1cff/TrickyStore) by 5ec1cff

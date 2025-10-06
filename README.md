# Play Integrity Fix-NEXT
Originally created by chiteroman, forked by me. This module is a set of experimental items to ensure valid attestation on rooted devices with the new PlayIntegrity API rules and DroidGuard restrictions. Avaliable on Android 10-16.

[![GitHub release (latest by date)](https://img.shields.io/github/v/release/EricInacio01/PlayIntegrityFix-NEXT?label=Release&color=blue&style=flat)](https://github.com/EricInacio01/PlayIntegrityFix-NEXT/releases/latest)
[![GitHub Release Date](https://img.shields.io/github/release-date/EricInacio01/PlayIntegrityFix-NEXT?label=Release%20Date&color=brightgreen&style=flat)](https://github.com/EricInacio01/PlayIntegrityFix-NEXT/releases)
[![GitHub Releases](https://img.shields.io/github/downloads/EricInacio01/PlayIntegrityFix-NEXT/latest/total?label=Downloads%20%28Latest%20Release%29&color=blue&style=flat)](https://github.com/EricInacio01/PlayIntegrityFix-NEXT/releases/latest)
[![GitHub All Releases](https://img.shields.io/github/downloads/EricInacio01/PlayIntegrityFix-NEXT/total?label=Total%20Downloads%20%28All%20Releases%29&color=brightgreen&style=flat)](https://github.com/EricInacio01/PlayIntegrityFix-NEXT/releases)

## Required
First, install one of these TrickyStore versions:
- [TrickyStore](https://github.com/5ec1cff/TrickyStore/releases)
- [TrickyStore-OSS](https://github.com/beakthoven/TrickyStoreOSS/releases)

You must have **one** of the following combinations installed (use latest versions):

| Root Solution | Zygisk Implementation | Additional Notes |
|---------------|----------------------|------------------|
| [Magisk](https://github.com/topjohnwu/Magisk) | [Zygisk Next](https://github.com/Dr-TSNG/ZygiskNext) or [ReZygisk](https://github.com/PerformanC/ReZygisk) | ⚠️ Disable Zygisk in Magisk settings |
| [KernelSU](https://github.com/tiann/KernelSU) | [Zygisk Next](https://github.com/Dr-TSNG/ZygiskNext) or [ReZygisk](https://github.com/PerformanC/ReZygisk) | Install as module |
| [KernelSU Next](https://github.com/KernelSU-Next/KernelSU-Next) | [Zygisk Next](https://github.com/Dr-TSNG/ZygiskNext) or [ReZygisk](https://github.com/PerformanC/ReZygisk) | Install as module |
| [APatch](https://github.com/bmax121/APatch) | [Zygisk Next](https://github.com/Dr-TSNG/ZygiskNext) or [ReZygisk](https://github.com/PerformanC/ReZygisk) | Install as module |


## 📝 NOTES
PIF-Next is not a root hiding module. It only has integration with TrickyStore to ensure valid hardware attestation and predefined settings to guarantee stable and excellent usability for later configuration.

## 🔍 CHECK INTEGRITY

There are two reliable methods for verifying Play Integrity verdicts:

1. **Google Play Store**:
   - Open the Play Store > Settings > Tap ‘Play Store version’ seven times.
   - Go to ‘General’ > ‘Developer options’ > ‘Verify integrity’.
   - Your attestation will appear immediately!

2. **External app - SPIC**:
   - Download [SPIC - Play Integrity Checker](https://play.google.com/store/apps/details?id=com.henrikherzig.playintegritychecker&pcampaignid=web_share).
   - Open the app and click ‘Check’ to view the results.


After requesting an attestation, you should receive something like this:
```text
- MEETS_BASIC_INTEGRITY     ✅
- MEETS_DEVICE_INTEGRITY    ✅
- MEETS_STRONG_INTEGRITY    ❌ (available with valid keybox)
- MEETS_VIRTUAL_INTEGRITY   ❌ (only for emulators)
```


## 🐛 KNOWN ISSUES
- Google Wallet: there is no magic formula that makes GWallet work on all devices. By default, PIF-Next comes with all options enabled and configured to ensure compatibility.
- Conflicts: some Custom ROMs (e.g. CrDroid, InfinityX, Matrixx, etc.) already come with Keybox injection by default. Instead of using this module, you can just use TrickyStore + Keybox injection from your own ROM.

## 🔄 TROUBLESHOOTING
You can follow [this tutorial](https://t.me/bunkerdoquim/26) (you will be redirected to Telegram) to fix all available issues.


## ACKNOWLEDGMENTS
- This project is forked from the official chiteroman's PIF repo.
- [kdrag0n](https://github.com/kdrag0n/safetynet-fix) & [Displax](https://github.com/Displax/safetynet-fix) for the original idea.
- [osm0sis](https://github.com/osm0sis/PlayIntegrityFork) for his autopif.sh, spoofBuild and some infrastructure integrations.
- [5ec1cff](https://github.com/5ec1cff/TrickyStore) by inserting keybox.xml and also target.txt in TrickyStore
- [KOWX712](https://github.com/KOWX712/PlayIntegrityFix) through its code base.

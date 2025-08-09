# Play Integrity Fix-NEXT
Created by chiteroman, forked by me. This module aims to ensure valid attestation on rooted devices running Android 8-16.
[![GitHub release (latest by date)](https://img.shields.io/github/v/release/EricInacio01/PlayIntegrityFix-NEXT?label=Release&color=blue&style=flat)](https://github.com/EricInacio01/PlayIntegrityFix-NEXT/releases/latest)
[![GitHub Release Date](https://img.shields.io/github/release-date/EricInacio01/PlayIntegrityFix-NEXT?label=Release%20Date&color=brightgreen&style=flat)](https://github.com/EricInacio01/PlayIntegrityFix-NEXT/releases)
[![GitHub Releases](https://img.shields.io/github/downloads/EricInacio01/PlayIntegrityFix-NEXT/latest/total?label=Downloads%20%28Latest%20Release%29&color=blue&style=flat)](https://github.com/EricInacio01/PlayIntegrityFix-NEXT/releases/latest)
[![GitHub All Releases](https://img.shields.io/github/downloads/EricInacio01/PlayIntegrityFix-NEXT/total?label=Total%20Downloads%20%28All%20Releases%29&color=brightgreen&style=flat)](https://github.com/EricInacio01/PlayIntegrityFix-NEXT/releases)

To use this module, you need to have [TrickyStore](https://github.com/5ec1cff/TrickyStore/releases) pre-installed. You also need one of the following (latest versions):

- [Magisk](https://github.com/topjohnwu/Magisk) with [ReZygisk](https://github.com/PerformanC/ReZygisk) and Zygisk disabled in Magisk settings
- [KernelSU](https://github.com/tiann/KernelSU) with [Zygisk Next](https://github.com/Dr-TSNG/ZygiskNext) or [ReZygisk](https://github.com/PerformanC/ReZygisk) module installed.
- [KernelSU Next](https://github.com/KernelSU-Next/KernelSU-Next) with [Zygisk Next](https://github.com/Dr-TSNG/ZygiskNext) or [ReZygisk](https://github.com/PerformanC/ReZygisk) module installed.
- [APatch](https://github.com/bmax121/APatch) with [Zygisk Next](https://github.com/Dr-TSNG/ZygiskNext) or [ReZygisk](https://github.com/PerformanC/ReZygisk) module installed.

# 📝 NOTES
The goal of this module isn't to hide root but to ensure valid attestation. At most, it applies a customized target.txt for TrickyStore to improve compatibility and ensure greater stability.

# ✅ CHECK VEREDICTS

There are two reliable methods to check your PlayIntegrity veredicts:

- Go to the Play Store > Settings > Tap 'Play Store version' seven times > 'General' > 'Developer options' > 'Verify integrity' - There you go, your attestation will appear!
- Download [SPIC - Play Integrity Checker](https://play.google.com/store/apps/details?id=com.henrikherzig.playintegritychecker&pcampaignid=web_share) and click 'Check' to view your attestation.


After requesting an attestation, you should get this result:
```text
- MEETS_BASIC_INTEGRITY   ✅
- MEETS_DEVICE_INTEGRITY  ✅
- MEETS_STRONG_INTEGRITY  ❌ (you can get using a valid keybox)
- MEETS_VIRTUAL_INTEGRITY ❌ (this is for emulators only)
```


# 💡 TIPS
Here are some personal recommendations for modules you can use alongside PIF-Next:

- [ReZygisk](https://github.com/PerformanC/ReZygisk) by PerformanC - an excellent open-source substitute for Zygisk Next.
- [Hide Folders](https://github.com/Doze-off/Hide-folders-files) by Doze-off - hides folders and files that detect your device as a Custom ROM. It also hides some LSposed items.
- [TreatWheel](https://t.me/zygote64_32/11) - i think it's a great alternative to Shamiko. it removes some detection points, too useful.


# 🐛 KNOWN ISSUES
- **spoofVendingSdk:** this option is disabled by default, spoofing the SDK version to 32 in the Play Store if you have an Android 13 or higher device. If you're on Android 12 or lower, this won't work. There are some known issues when enabling this:
	-   The back gesture/navigation button in the Play Store takes you straight to the home screen for all devices.
	-   Blank account sign-in status and broken app updates on ROMs running Android 14 or later.
	-   Incorrect app variants may be served for all devices.
	-   Full Play Store crashes for some setups.

- **spoofProvider:** custom keystore provider. Some users who use GWallet have reported that enabling this causes contactless payments to stop working. It’s recommended to disable it if you frequently use contactless payments (NFC).

- **spoofVendingSDK:** google has patched the spoofVendingSdk, so device verdict on Android 12+ or later with spoofVendingSdk is no longer achievable.

# 🔄 TROUBLESHOOTING

- **Google Walllet issues:**



	- Enable spoofBuild
	- Disable spoofProvider (this break GWallet).
	- Você precisa de uma Keybox Válida para ter a carteira funcionando, assim é possível adicionar seu cartão.
	- If you have a revoked or soft banned Keybox, the wallet will work, but only if you already have the card added, you can't add new cards.

> You can also follow the [PIF-Next](https://t.me/bunkerdoquim/26)  guide (you will be redirected) to Telegram for better certification with this module.

Thanks to [Joaquim](https://t.me/bunkerdoquim) for creating the guide and also these warnings.



- **Failing BASIC integrity:**
	- If you are failing MEETS_BASIC_INTEGRITY something is wrong in your setup. Recommended steps in order to find the problem:

	- Disable all modules except this one
	- Fetch a new pif.json (you can do this on PIF-Next WebUI)

# ACKNOWLEDGMENTS
- [kdrag0n](https://github.com/kdrag0n/safetynet-fix) & [Displax](https://github.com/Displax/safetynet-fix) for the original idea.
- This project is forked from the official chiteroman's PIF repo.
- [osm0sis](https://github.com/osm0sis) for his original [autopif2.sh](https://github.com/osm0sis/PlayIntegrityFork/blob/main/module/autopif2.sh) script

# Changelog

PlayIntegrityFix-NEXT - fork by EricInacio01

## V3.0

- Added spoofBuild option.
- Updated Fingerprint
- Synced with latest security patch (2025/08/05)
- New injection mechanism to guarantee DEVICE_INTEGRITY
- Improved TrickyStore integration: the module will now install the latest version of TS if you don't have it installed.
- TrickyStore integration mechanism changed for better GWallet support
- Improved injection to Android 16
- Added small hooks to mask DroidGuard
- Added new script 'killpi.sh' to eliminate GMS processes robustly (credits: [@osm0sis](https://github.com/osm0sis/PlayIntegrityFork/blob/main/module/killpi.sh)) 
- Small changes in WebUI
- Fixed a bug where the WebUI displayed a white screen
- Fixed formatting of a key structure

## v2.1

- Updated Fingerprint.
- Added new Props by default for better attestation.

## v2.0


- NEW: Support for Android 16.
- CHANGED: SpoofVendingSDK is now disabled by default.
- NEW: New fingerprint and updated keybox.
- NEW: New injections added for improvements and compatibility.
- NEW: New method to ensure valid attestation on all devices.
- NEW: New and improved TrickyStore detection system: now matches the module's target.txt with TrickyStore's, preventing loss of personal settings.
- NEW: New keybox.xml system: PIF-Next detects if an alternative keybox is installed and asks if you want to replace it with PIF-Next's keybox.
- FIXED Fixed crashes in the Play Store on Android 14 and above, even with SpoofVendingSDK disabled.
- FIXED: Fixed an issue where the WebUI crashed on some devices.
- FIXED: Fixed PIF-Next functionality with ReZygisk, with reorganized structures for better compatibility.

## v1.7


- Updated Fingerprint;
- New Keybox (only for DEVICE_INTEGRITY);
- Added Google Services Framework to the target.txt list;
- Now the module detects if your device is running Android 14 or higher and asks whether you want to apply SpoofVendingSdk;
- Improvements to the organization and structure of the module 
- The module now supports “OTA” updates via your root solution (Magisk, APatch, KernelSU/Next).

## v1.5


- New WebUI! ✨
- New Keybox for DEVICE_INTEGRITY only
- Added Google Wallet in target.txt, for injection into TrickyStore automatically.
- Fixed an issue where PIF didn't detect certain Custom ROMs as AOSP (Thanks: [KOW](https://github.com/KOWX712/PlayIntegrityFix)
- Fixed an issue where AutoPIF crashed when requesting a new fingerprint
- Improved injection into Custom ROMs
- Improved Tricky Store detection, now the module will cancel the installation if TrickyStore is not installed.
- Improved KSUWebUI integration 
- Improved injection on Android 15

## v1.0

- FIRST LAUNCH!
- I'll be as honest as I can, even though I'm not an expert, I'm happy to show you a solution.
- I've done my best to give full credit to the many incredible developers who have built this community project.
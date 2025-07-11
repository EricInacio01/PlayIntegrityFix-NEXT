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
- Fixed an issue where PIF didn't detect certain Custom ROMs as AOSP (Thanks: KOW
- Fixed an issue where AutoPIF crashed when requesting a new fingerprint
- Improved injection into Custom ROMs
- Improved Tricky Store detection, now the module will cancel the installation if TrickyStore is not installed.
- Improved KSUWebUI integration
- Improved injection on Android 15
# Changelog

Play Integrity Fix [INJECT] - fork by KOWX712

## v4.1

- Update fingerprint.
- Migrate from json to prop (pif.json -> pif.prop) for more optimized binary size.
- Added spoofBuild option.
- Auto reset pif.prop when the format is incorrect.
- Improved WebUI, fixed false error log.
- Added back module update.

## v3.3

- OTA update support for fp fetching script, now it can be updated without reboot, module's update will be less needed. (Thanks to @backslashxx)
- Magisk action redirect WebUI support, removed action button in KernelSU and APatch.
- Improved WebUI , better WebUI X support.

## v3.2

- update fingerprint.
- fix action failed to fetch `pif.json`.

## v3.1

- update fingerprint.
- add new ReZygisk directory on installation zygisk check.

## Diff with official inject v3

### v3-inject-vending

- based on official inject v3, no auto update
- added spoofVendingSdk
- added monet theme support in WebUI X

### v3-inject-manual

- based on `v3-inject-vending`
- removed auto config (tricky store and rom signature check)
- added manual conifg

---

## Known Issues

### Devices will experience degraded functionality in Play Store when spoofVendingSdk is enabled:

- Back gesture/nav button from within the Play Store exits directly to homescreen for all
- Blank account sign-in status and broken app updates for ROMs A14+
- Incorrect app variants may be served for all
- Full Play Store crashes for some setups

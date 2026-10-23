# Kingmakers RP client (SA-MP 2.10 base)

Android client for the **official GTA San Andreas engine** (the Google Play
version this client was made for), based on the SA-MP 2.10 sources by
kuzia15/bkuzn2. ARM64 only.

No Rockstar files are stored here. The **Build APK (2.10)** action takes the
engine (`libGTASA.so`, `libSCAnd.so`, `libImmEmulatorJ.so`) and the game
assets from your own GTA SA APK files at build time:

1. Copy the APK files of your Google Play install (for example with MT Manager:
   *Extract APK*): `base.apk` and the split whose name contains `arm64`.
2. Upload them somewhere private with direct-download links.
3. Add the repository secret `GTA_APK_URLS` with the links separated by a space.
4. Run **Actions → Build APK (2.10) → Run workflow** and download
   `kingmakers-2.10-debug-apk`.

`tools/check_engine.py` stops the build if `libGTASA.so` is not the official
engine this client needs (other game versions or modified copies would crash).

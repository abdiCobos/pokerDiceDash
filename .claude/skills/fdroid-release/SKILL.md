---
name: fdroid-release
description: Preparing a Poker Dice Dash release for F-Droid (applicationId, FOSS-only dependencies, metadata/fastlane, versioning, tags). Use when bumping the version, adding a dependency, or touching android/, metadata/ or fastlane/.
---

# F-Droid release checklist

- No proprietary services: no Firebase, Google Play Services, Crashlytics, analytics SDKs.
  `AppLogger` stays local-only (dart:developer).
- Every new dependency must be FOSS and must not download code/assets at runtime
  (e.g. bundle font files instead of google_fonts). Check `pubspec.lock` transitive deps.
- `pubspec.yaml`: version `x.y.z+code`; bump the build code every release.
- Release build must not use the debug signing config; F-Droid signs its own builds and
  `key.properties` stays out of git.
- Metadata recipe in `metadata/<applicationId>.yml` (License, SourceCode, IssueTracker,
  Categories, Builds pointing at a tagged `commit`, not a branch). Keep it in sync with the
  applicationId used in `android/app/build.gradle*` and the `MainActivity.kt` package.
- `fastlane/metadata/android/<lang>/`: title, short/full description, changelog for the new
  versionCode, icon and screenshots (take screenshots with the `visual-qa` skill if needed).
- Permissions only: INTERNET, ACCESS_NETWORK_STATE, ACCESS_WIFI_STATE,
  CHANGE_WIFI_MULTICAST_STATE, WAKE_LOCK, plus FOREGROUND_SERVICE, FOREGROUND_SERVICE_CONNECTED_DEVICE
  and POST_NOTIFICATIONS for KeepAliveService (own Kotlin service, no plugin: LAN games keep running
  while the player uses other apps; started/stopped from P2PService via BackgroundKeeper).
- Tag (`git tag vX.Y.Z`) only when the user asks; then point the recipe to the tag.
- No secrets or leftover service configs (`firebase.json`, `google-services.json`).

# Windows release (GitHub Releases)
- `powershell -ExecutionPolicy Bypass -File windows/packaging/build_release.ps1` builds and writes
  `dist/PokerDiceDash-<ver>-windows-x64.zip` and, with Inno Setup 6 installed (user scope, winget
  `JRSoftware.InnoSetup`), `dist/PokerDiceDash-<ver>-setup.exe`. `dist/` is git-ignored.
- The package bundles msvcp140/vcruntime140/vcruntime140_1 (app-local VC++ runtime), LICENSE.txt
  and LEEME.txt (SmartScreen + firewall instructions; never change those settings for the user).
- Never change the `AppId` GUID in `poker_dice_dash.iss`: upgrades depend on it. Version comes from pubspec.
- Test: silent install `/VERYSILENT /CURRENTUSER`, run the game, then uninstall from the registry's UninstallString.

# Testing the recipe in WSL Ubuntu (before tagging / sending the MR)
- Ubuntu already has `fdroidserver`, `openjdk-17-jdk-headless`, `unzip` (the user ran the sudo apt
  install; never type the sudo password). Use JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64 (default java is 25).
- Test fdroiddata at `~/fdroidtest/fdroiddata`: copy `metadata/<appid>.yml` there plus `srclibs/flutter.yml`.
  Categories must come from the REAL list (fdroiddata `config/categories.yml` / `schemas/metadata.json`):
  this app uses `Card Game` + `Dice`; the old generic `Games` is rejected by the CI schema check.
  Never dismiss a lint warning as a test-setup artifact without checking it against real fdroiddata.
- `fdroid lint <appid>` and `fdroid rewritemeta <appid>` (copy the rewritten file back: CI requires that format, LF).
- `fdroid scanner -v --exit-code <appid>` with `commit:` temporarily set to a pushed hash (restore it after).
  It requires `pubspec.lock` in git (`!pubspec.lock` in .gitignore).
- Full build like the buildserver: `~/fdroid_build.sh` (fresh clone, Flutter srclib tag, rm platforms,
  `flutter build apk --release`); APK must be unsigned and list only the allowed permissions.

- Every build entry builds with `--dart-define=UPDATE_CHECK=false`: the GitHub "new version" notice
  (lib/services/update_checker.dart) must be off in the F-Droid build (F-Droid updates and signs the
  app itself, and the app must not contact other servers there). test/update_checker_test.dart checks it.
- Bump `lib/app_version.dart` together with pubspec `version:` (a test compares them).
- Every build entry needs `ndk: <flutter.ndkVersion>` (Flutter 3.38.9 -> 28.2.13676358, see
  flutter_tools/gradle/.../FlutterExtension.kt). Local builds auto-download the NDK; the F-Droid buildserver does not.

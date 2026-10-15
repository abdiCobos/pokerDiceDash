---
name: fdroid-release
description: Use when preparing Poker Dice Dash for an F-Droid release (applicationId, metadata, dependencies, signing, build recipe).
---

# F-Droid checklist

- No proprietary services: no Firebase, Google Play Services, Crashlytics, analytics SDKs. `AppLogger` must stay local-only.
- Change `applicationId`/`namespace` from `com.example.*` (e.g. `io.github.abdicobos.pokerdicedash`) and move `MainActivity.kt` accordingly; keep the fastlane/metadata file name in sync.
- `pubspec.yaml`: real description, version `x.y.z+code`; bump `versionCode` each release.
- Dependencies must be FOSS: check `pubspec.lock` (google_fonts downloads fonts at runtime - bundle the font files instead).
- Release build must not use the debug signing config; F-Droid signs its own builds, `key.properties` stays out of git.
- Metadata: `metadata/<applicationId>.yml` with License (GPL-3.0-or-later or the repo license), SourceCode, IssueTracker, Categories, Builds (tagged `commit`, not `master`).
- Add fastlane/metadata/android/<lang>/ with title, short/full description, icon and screenshots.
- Permissions: only INTERNET, ACCESS_NETWORK_STATE, ACCESS_WIFI_STATE, CHANGE_WIFI_MULTICAST_STATE, WAKE_LOCK.
- Tag the release (`git tag v1.0.0`) and point the recipe to the tag.
- Repo must contain no secrets or leftover service configs (`firebase.json`, `google-services.json`, rules files).

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
  CHANGE_WIFI_MULTICAST_STATE, WAKE_LOCK.
- Tag (`git tag vX.Y.Z`) only when the user asks; then point the recipe to the tag.
- No secrets or leftover service configs (`firebase.json`, `google-services.json`).

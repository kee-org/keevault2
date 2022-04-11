# Release procedures

**These instructions only work for luckyrat.**

## Before any of the below tasks

(For new client machines) check that ~/keystore-kv-play.jks exists
cd android
Set env variables by executing the code in the "Setup Env" field of these entries:
1. "Google Play Console API"
2. "Android kv-play keystore"

## Release to "internal" testing group

```
flutter build appbundle --dart-define KEEVAULT_STAGE=prod --dart-define KEEVAULT_CHANNEL=play
bundle exec fastlane internal
```

## Promote latest "internal" release to "alpha" testing group

Create <=500 characters of release notes: android/fastlane/metadata/android/en-GB/changelogs/<release number>.txt

bundle exec fastlane alpha

## Promote latest "alpha" release to "beta" testing group

bundle exec fastlane beta
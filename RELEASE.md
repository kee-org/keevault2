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
flutter build appbundle --dart-define KEEVAULT_STAGE=prod --dart-define KEEVAULT_CHANNEL=play --dart-define IAP_GOOGLE_PLAY=yes
bundle exec fastlane internal
```

## Promote latest "internal" release to "alpha" testing group

Create <=500 characters of release notes: android/fastlane/metadata/android/en-GB/changelogs/<release number>.txt

bundle exec fastlane alpha

## Promote latest "alpha" release to "beta" testing group

bundle exec fastlane beta

## Updating screenshots

We use Patrol integration testing framework to orchestrate navigation through the app to the various places we need to take a screenshot for use in app stores.

0. Build:

ios:

```
# seems to be necessary to clean and rebuild in order to swap between integration test support and general development/debugging support
# run project clean from xcode
# CLOSE XCODE
flutter clean
flutter build ios --config-only integration_test/manual_screenshots_test.dart
#cd ios
#pod install --repo-update # not necessary cos flutter build does this already, I think.
#cd ..
```

android:

```
flutter clean
flutter build android --config-only integration_test/manual_screenshots_test.dart
```

1. Check that only one device is present (manually stop and start simulators and unplug physical devices as necessary)

```
patrol devices
```

2. Start the test

```
patrol test --target integration_test/manual_screenshots_test.dart --verbose --no-label
```

3. Clear the system clipboard and check that "enable clipboard sharing" in android extended controls is disabled (it seems to cache the contents of host clipboard even after we wipe it).

```
pbcopy < /dev/null
```

4. Click the screenshot button each time we pause for that operation to happen

5. Go to where the simulators store the screenshots and upload them to whatever we use to convert them into something prettier

6. Export from that online tool and manually upload them to Apple App Store (later run `fastlane deliver init` and then automate this) and put them into the correct fastlane metadata location for Google Play screenshots (and later the automated Apple app store)

## Target screenshot devices / types

* iPhone 5.5" = iPhone SE (3rd gen) 16.4
* iPhone 6.5" = iPhone 14 Plus 16.4
* iPad = iPad Pro 12.9" 16.4
* Android phone = Nexus 6 (16:9) API 33
* Android tablet = Nexus 10 API 31 (do not go higher than this API until Google has enabled a way for us to hide the huge bottom taskbar introduced in API 32)


# Renewing Apple certificates

* Might cause TestFlight builds to become invalidated?

```
cd ios
bundle exec fastlane match nuke development
bundle exec fastlane match nuke distribution
bundle exec fastlane generate_new_certificates
bundle exec fastlane iapdevcert
```
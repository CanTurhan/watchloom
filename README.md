# Watchloom

Watchloom tracks TV series, episode progress, release reminders and monthly viewing activity in English and Turkish. Guest library data stays on the device. An optional Watchloom account adds cloud backup and recovery.

Free includes up to 5 saved shows. The optional monthly Premium subscription unlocks an unlimited library and removes banner ads. Advertising requires a separate, revocable user choice. Purchases use StoreKit 2; local prices come from the App Store.

Build 1.1.0 (6) adds optional Firebase accounts (Apple, Google, email), separate
guest/account libraries and cloud backup with conflict handling and in-app
account deletion. The iOS client is configured for Firebase project `watchloom-canturhan`;
Apple provider settings were saved and read back successfully in the owner's Terminal.
The owner completed email-source/SPF registration. Signed distribution and real-device
tests on TestFlight remain pending. Spark Firestore rules/indexes were deployed and verified on November 5, 2026; Firebase iOS security patch 12.19.3 is installed and the unsigned integration archive compiles. Follow
[FIREBASE_SETUP.md](FIREBASE_SETUP.md) before building or uploading this branch.

## Development

Flutter/Dart versions follow `pubspec.yaml`. iOS deployment target: **15.0**. Install Xcode and CocoaPods, then:

```bash
flutter pub get
flutter analyze --no-pub lib test
flutter test --no-pub
```

## iOS release

```bash
bash scripts/release_ios.sh --check
bash scripts/release_ios.sh --archive-xcode
```

The Xcode command builds a QA archive and exports an IPA with test ads; it does not upload it. Production uses `--build`. To build and upload a QA release for TestFlight, use `--upload-testflight`; `--upload-existing` retries distribution of a verified archive. Every uploaded build needs a unique build number. The release script validates archive/IPA metadata and native Firebase SDK versions, and preserves previous artifacts outside the current output path.

See [Premium release steps](WATCHLOOM_PREMIUM_RELEASE.md) and the [App Store audit](APP_STORE_AUDIT.md) for Store setup, legal/provider checks and the outstanding device tests.

After updating native dependencies, regenerate the bundled license notices:

```bash
cd ios
pod install
cd ..
python3 scripts/sync_ios_licenses.py
```

## Data attribution

TVmaze provides show metadata under [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/). Source and license links appear in the app and exported viewing summaries. This does not license Watchloom's application code or a user's personal notes as TVmaze data. See [TVmaze's API terms](https://www.tvmaze.com/api#licensing) and [copyright policy](https://www.tvmaze.com/site/copyright) for the source data and artwork.

Web support, privacy and terms pages are in `docs/`; changing them locally does not publish them.

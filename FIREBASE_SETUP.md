# Watchloom accounts and backup — 1.1.0 (6)

Current branch: `feature/firebase-auth-sync`. The published `version_1.1.0_5`
snapshot is preserved. This rollout uses **Firebase Spark only**. Do not link a
billing account or deploy Functions, Cloud Run, Scheduler or Storage.

## Verified configuration — November 5, 2026

| Item | State |
| --- | --- |
| Project | `watchloom-canturhan` |
| Project number | `157774090938` |
| iOS bundle | `com.canturhan.watchloom` |
| Firebase iOS app | `1:157774090938:ios:a93902423dc949f20d2883` |
| Apple team | `GC8Z24R23C` |
| Email/Password and Google | Enabled by the owner; device sign-in still to test |
| Native plist, Dart options and Google callback | Configured and matching |
| Billing | No linked billing account, verified by the deployment helper |
| Firestore | Default Standard/Native database created in `europe-west1` |
| Rules and indexes | Deployed; eight emulator checks passed; anonymous user/marker reads denied |
| Apple App ID capability | Enabled in Developer portal by the owner; Runner entitlement/automatic signing configured for Debug, Profile and Release |
| Apple Service ID | Owner confirmed `com.canturhan.watchloom.auth`, Watchloom primary App ID and Firebase handler domain/return URL saved |
| Apple key | Created by the owner; local P-256 format validated; repository copy moved outside Git with owner-only permissions |
| Apple provider | Configured and read back in the owner's Terminal: enabled, expected Service ID/team/key/bundle matched |
| Apple email relay | Owner reported default sender registration and SPF completed; actual delivery remains to test |
| Remaining Apple checks | Signed entitlement/profile, device sign-in, email delivery and token revocation/deletion through TestFlight QA |
| Firebase iOS security patch | 12.19.3 installed; fresh unsigned Release archive compiled and SDK bundle versions verified |

The deployment receipt is local at `build/release-audit/firestore-deployment.json`.
It records the tested rules hash and project. It is not a substitute for account,
backup and deletion tests with real provider sessions.

## Authentication setup

Keep Email/Password (not email-link sign-in) and Google enabled in Firebase
Authentication. Use the monitored support address `can.turhan.web@gmail.com` in
provider settings. Confirm email enumeration protection, a minimum eight-character
password policy, verification/reset templates and working action URLs in Console.
Do not assume these remote settings from the client implementation.

For Apple, follow the [step-by-step portal guide](APPLE_SIGN_IN_SETUP.md). After
the Apple key and Service ID exist, `node scripts/configure_firebase_apple.cjs
--configure` connects the provider through the existing CLI login, suppresses
private request/response body logs and verifies the saved public settings. The
key must remain outside the repository. `--check` is read-only. No paid service
or Identity Platform upgrade is requested.

For Apple:

1. Apple Developer → Certificates, Identifiers & Profiles → Identifiers →
   `com.canturhan.watchloom`: enable Sign in with Apple for team `GC8Z24R23C`.
   Refresh the signing profile. Source entitlements cover Debug, Profile and
   Release; confirm the entitlement in the signed application too.
2. Firebase Console → Authentication → Sign-in method → Apple: enable the
   provider and configure the Apple OAuth values required for token revocation.
   Use a Service ID associated with this primary App ID, Team ID, Key ID and
   the corresponding private Apple key in the provider console.
3. Register the exact Firebase return URL when configuring the Service ID:
   `https://watchloom-canturhan.firebaseapp.com/__/auth/handler`.
   For Hide My Email, configure Apple's private-email relay as required by
   Firebase, including `noreply@watchloom-canturhan.firebaseapp.com` when using
   the default Firebase sender. Test delivery and account deletion on a device.
4. Private `.p8` keys, Firebase admin credentials, passwords and review test
   credentials stay out of this repository and chat.

The downloaded root `GoogleService-Info.plist` is ignored. The canonical public
client file is `ios/Runner/GoogleService-Info.plist`. If it changes, run:

```bash
python3 scripts/configure_firebase_ios.py /path/to/GoogleService-Info.plist
python3 scripts/check_firebase_release.py
```

The generator preserves unrelated URL schemes and refuses mismatched client or
bundle identifiers. Public Firebase API keys are not server credentials; keep
appropriate API/application restrictions and test Auth/Firestore with the final
restriction configuration.

Google scene compatibility: the pinned `google_sign_in_ios` 5.9 plugin uses
AppDelegate callbacks. `WatchloomGoogleScenePlugin` bridges Google URLs through
Flutter's UIScene dispatcher and is retained by the plugin registrar. Test
browser return and cancellation. Remove this bridge only after a tested plugin
upgrade supplies native scene support.

## Spark deployment and security model

From a normal Mac Terminal with the existing Firebase CLI login:

```bash
bash scripts/deploy_firebase.sh --check
bash scripts/deploy_firebase.sh --deploy
```

The helper detects an installed Java 21+ runtime, including Android Studio's JDK.
It tests rules against loopback-only demo emulators, verifies billing is unlinked,
prepares the Firestore API, checks/creates the default database and deploys only
rules/indexes. Existing databases in another region/type are left unchanged and
cause a stop. No paid backend or administrative credential is created. A failure
prints its phase; credentials are never printed. For an isolated connection/plan
check, run `node scripts/check_firebase_spark.cjs watchloom-canturhan --enable-firestore`.

Rules allow verified owners to create an exact-schema root and immutable backup
snapshots/chunks. They reject anonymous access, other accounts, arbitrary root
fields, forged Premium flags, stale revision updates and changes to completed
chunks. Password users must verify their email; Google/Apple eligibility follows
the current token's provider. Listing other users or deletion markers is denied.
Firestore disk persistence is off; the app uses separate per-account SQLite caches.
App Check enforcement is not configured. Do not enable enforcement until the
client and debug/TestFlight/production attestation paths have been tested.

Deletion requires fresh reauthentication. An atomic marker/root lock stops all
client backup writes before snapshots are erased. The client removes every backup
and chunk, removes the owner root, then deletes the Firebase Auth identity. A linked
Apple authorization is revoked with a fresh authorization code. Interrupted work
keeps the identity available for reauthentication and completion; the UI locks the
account library when a pending deletion is detected.

A minimal replay-protection marker blocks still-valid old Firebase ID tokens.
It holds UID, timestamps and a random completion proof, without email, name or
viewing content. Only the private proof can complete a purged marker; rules permit
removal only after the server's two-hour safety window. The app retries completion,
local cache cleanup and expired marker cleanup on startup/foreground. There is no
paid background worker: a marker can remain if the app is removed before cleanup.
The privacy policy discloses this and offers private support for cleanup requests.

Spark has finite service quotas. Exhaustion pauses backup and keeps local changes;
it does not authorize billing or promise unlimited cloud storage. Check Console
usage during rollout. Backup payloads and hashes are excluded from indexes.

## Data and user experience

- Existing guest records remain in `watchloom.db`. Schema 5 adds transactional
  revision tracking. Account SQLite file names are SHA-256 hashes of Firebase UID.
  Switching accounts resets navigation, notifications and generated share images.
- Guest copying is explicit and only enters an empty synchronized account. The
  original guest library remains. Legacy records above five are preserved;
  additions continue to follow the existing StoreKit-verified Free/Premium policy.
- A five-second debounce backs up account changes. Reinstall checks the cloud
  before any upload. Restore validates schema, SHA-256 and bounded gzip JSON;
  concurrent local edits abort replacement. Conflicts require an explicit choice.
- Snapshots use 400 KiB chunks and small batches. A 64 MiB uncompressed snapshot
  limit is reported as a backup failure without deleting local records. Cloud
  backup is not end-to-end encrypted. Transport/storage protections and rules
  apply; authorized administrators can access service data for administration.
- Active and previous snapshots are protected. The client prunes older snapshots
  after 24 hours during backup. There is no scheduled server cleanup.
- Signing out leaves that account's local cache and opens the guest library.
  Unsaved changes are warned about. Deleting an app before backup completes can
  lose local changes. iOS Keychain may retain authentication across reinstall;
  restored sessions still never silently import guest records.
- StoreKit 2 alone grants Premium. Firebase identity and Firestore fields cannot
  grant/transfer/cancel subscriptions. Account deletion includes a separate Apple
  subscription-management action and keeps the independent guest library.

## Native security update and release gates

Firebase's October 22 security backport removes compromised CA roots from the
Firestore trust store. Keep `$FirebaseSDKVersion = '12.19.3'` in `ios/Podfile`.
Its official component versions are Core/Firestore/Internal 12.19.3 and Auth
12.19.0; the umbrella version is not every component's version.

```bash
bash scripts/update_ios_dependencies.sh
```

This updates the Firebase native dependency family, validates the installed
lockfile and regenerates license notices. The old SDK 12.6 integration archive is
historical compilation evidence and must not be distributed. Release checks inspect
both the lockfiles and SDK resource versions in the actual archive/IPA to reject
stale artifacts. Rebuild after updating dependencies.

Local checks: **51 Flutter tests, 21 Python checks and 7 Node setup/guard tests passed**.
Dart analysis is clean. The owner's normal Terminal ran **8 successful Firebase
emulator checks** and the deployment's live anonymous-denial probes. The security-patched unsigned Release archive compiled at
`build/ios/archive/AuthSpark-SecurityPatch-Unsigned.xcarchive`, version 1.1.0 (6),
iOS 15.0, with matching project and SDK resource versions. Signed distribution
and real-device behavior are still pending.

The owner chose TestFlight for device QA. The technical checks below permit
preparing a QA build; device rows remain open until that build is installed and
tested. A successful upload is not device-test completion or approval for Review.
The signed archive attempt in the restricted agent session failed with No Accounts
and no matching provisioning profile; no signing identity was visible in Keychain.
Run signed distribution from the owner's normal Mac Terminal/Xcode account.

Before production submission (device checks run on TestFlight):

- Real-device Apple, Google and email sign-in, cancel/error, Hide My Email,
  verification/resend/reset, provider linking and expired-session behavior.
- Guest import, account switching, offline edits, concurrent devices/conflicts,
  reinstall restoration with the same Firebase identity, and failed-copy recovery.
- Delete each provider account: inspect Auth, all backup/chunk documents and local
  cache; test interrupted deletion and an already signed-in second device. Confirm
  stale tokens cannot recreate records and marker cleanup obeys the safety window.
- Restore Premium with the same Apple Account, including guest mode; signing in to
  Firebase alone must not unlock it. Finish the StoreKit/ads device checks in the
  [Premium release guide](WATCHLOOM_PREMIUM_RELEASE.md).
- Publish the matching EN/TR privacy/terms/support pages; verify public URLs.
  Update App Privacy for identity, supplied email/name and uploaded library/notes/
  history alongside the native advertising SDK report. Firebase Analytics is off.
- Review provider processing/transfer arrangements and store commercial details
  with the owner. Source text cannot confirm external agreements or legal filings.

Run `bash scripts/release_ios.sh --check` after setup, then the documented signed
build command. QA builds with demo ads require a newly numbered production build
before Review. No build-6 TestFlight upload or App Review submission is recorded.

References: [Apple sign-in](https://firebase.google.com/docs/auth/ios/apple),
[Firebase pricing plans](https://firebase.google.com/docs/projects/billing/firebase-pricing-plans),
[Firestore rules](https://firebase.google.com/docs/rules),
[Firebase iOS release notes](https://firebase.google.com/support/release-notes/ios),
[Firebase privacy](https://firebase.google.com/support/privacy),
[Apple account deletion](https://developer.apple.com/help/app-review/guideline-reference/5-1-1-account-deletion).

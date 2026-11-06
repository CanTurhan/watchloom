# Watchloom 1.2.0 (7) — community and viewing overview

Delivery branch requested by the owner: `version_1.1.0_6`. Preserve original `ccafccd` before advancing it. Binary version is independent of the branch name; `1.1.0 (6)` was already submitted to Apple. This change is series-only. No movie catalog, movie counters or movie storage migration are included.

## Service boundaries

| Project | Bundle | Firebase | Source |
| --- | --- | --- | --- |
| Watchloom | `com.canturhan.watchloom` | Existing `watchloom-canturhan`, Spark plan | `CanTurhan/watchloom`, requested delivery branch above |
| Puzzle Music Sort | `com.canturhan.puzzlemusicsort` | Separate live project proposed; not provisioned | Separate local `puzzle_music_sort` repository, version `0.1.0+1`; remote creation pending |

Apple developer team may be shared, but bundle IDs, application data, products, source repositories, build sequences and Firebase projects are separate. No game Firebase or Apple key is copied from Watchloom.

## Community behavior

New comments and replies are pending until an authorized operator approves them. Public display identity is chosen explicitly; Firebase account email/real name is not automatically copied to comments. A nickname is a display choice, not anonymity from security administration. The composer validates text, and Firestore rules enforce pending-only submission, schema, ownership, rate limits and private administrative data. Moderator approval remains required; a keyword list cannot reliably understand every language or context.

Provide own-comment deletion, spoilers, reporting, private blocks and a private support address. Account deletion must remove authored comments, private profile/handle, own block list and own report references before deleting Auth. Other authors' replies remain independently authored; a deleted parent must not retain the deleted author's label/body. A minimal random deleted UID can remain in another user's private suppression preference; the public policy explains administrative cleanup requests.

Operate the moderation queue and reports regularly and handle urgent reports promptly. Keep publishing disabled until a real moderator UID is configured and the operator accepts that responsibility. Reporting/takedown must remain available when new publication is paused. No Blaze upgrade is part of this release.

An older v6 client cannot finish account deletion while a community profile exists. The updated app removes owned community records before deleting that profile and completing the existing cloud/Auth flow. This prevents the older deletion path from silently leaving new public content behind.

Owner Terminal release entry point: `bash scripts/ship_testflight.sh`. It runs the full Auth/Firestore authorization tests and verified Spark deployment before the signed QA archive/upload, and stops on any failed phase. There is no skipped-security mode. Configure the verified operator UID through `scripts/community_moderation.cjs` as documented in `firebase/COMMUNITY_MODERATION.md`; public posting stays unavailable until that operation succeeds.

## App Store Connect changes before App Review

- Update the age-rating questionnaire for **User-Generated Content** and **Messaging and Chat** (Apple's definition includes public posting), and retain the accurate advertising answer. Use Apple's calculated regional ratings and any necessary higher override; do not invent a universal age rating from a keyword filter.
- Review App Privacy for account identifiers, supplied name/email and **Other User Content** (comments, replies, private uploaded notes/library, reports), linked to the account for app functionality. A nickname does not de-identify the stored account UID. Keep the existing advertising/SDK disclosure review; do not copy the app-owned manifest as the complete vendor answer sheet.
- Public URLs: privacy.html, privacy-choices.html, terms.html, support.html, community.html and licenses.html on the existing Watchloom GitHub Pages site. Publish and verify the new pages before reviewer access. Bundled license notices remain available offline.
- Review notes should explain the pending moderation state, report/block/delete controls, series-only scope and optional account flow. Provide the reviewer with a working account or supported sign-in access as required; never post account credentials in source or public issues.
- TestFlight uses test ads. A later production archive needs production ad configuration and a fresh build number; owner performs the final App Review/live decision.

## Validation record

Source validation on November 6, 2026: 108 Flutter tests, 25 Python tests and 15 Node tests passed; Dart analysis and whitespace checks clean. The visual harness generated phone/tablet-size previews including 320 px at 180% text, with zero reported Flutter layout/exception errors. Cached official Firestore compiler validated rules syntax/types and all 13 literal RE2 patterns.

Full Auth/Firestore emulator authorization tests could not bind localhost ports in the managed session (EPERM); these tests are not reported as passing. Firebase CLI reauthentication was completed by the owner, but Google API DNS/network access remains unavailable here (ENOTFOUND). New live rules/indexes/config, signed archive/upload, Apple sign-in and cross-user device tests remain unverified. The owner's release entry point enforces the missing emulator/deployment checks before upload. A source commit does not prove TestFlight processing or moderation operation.

## Primary references

- [Apple App Review Guidelines, including 1.2](https://developer.apple.com/app-store/review/guidelines/)
- [Apple age-rating definitions](https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions/)
- [Apple App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/)
- [Apple privacy manifest data collection](https://developer.apple.com/documentation/bundleresources/describing-data-use-in-privacy-manifests)
- [Firestore security rules conditions](https://firebase.google.com/docs/firestore/security/rules-conditions)

This record describes implementation and release checks. It does not certify compliance with every country's law or guarantee the absence of bugs.

## Owner-run release follow-up

The owner confirmed the QA upload command completed. App Store Connect processing and real-device behavior remain owner checks. The local deployment receipt records a successful emulator-tested rule deployment at 2026-11-06T06:04:55.321764+00:00; its rule hash matches the current source.

Moderator initialization was attempted with the literal `FIREBASE_UID` placeholder and therefore did not enable posting. The operator helper now rejects these example identifiers before remote access and supports owner-only `init --email EMAIL` resolution to a unique existing, enabled and verified Firebase Auth UID. No account is created and no email is stored as a role. Its updated Node suite passed 19 tests. This CLI-only change requires no new iOS build. Moderation activation remains pending a successful operator command and status verification.

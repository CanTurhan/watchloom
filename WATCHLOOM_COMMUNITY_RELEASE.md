# Watchloom 1.2.0 (8) — community and viewing overview

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

Operate the moderation queue and reports regularly and handle urgent reports promptly. Enable submission only after an authorized operator configures owner CLI moderation or a verified moderator UID and accepts that responsibility. Reporting/takedown remains available when new publication is paused. No Blaze upgrade is part of this release.

An older v6 client cannot finish account deletion while a community profile exists. The updated app removes owned community records before deleting that profile and completing the existing cloud/Auth flow. This prevents the older deletion path from silently leaving new public content behind.

Owner Terminal release entry point: `bash scripts/ship_testflight.sh`. It runs the full Auth/Firestore authorization tests and verified Spark deployment before the signed QA archive/upload, and stops on any failed phase. There is no skipped-security mode. Configure owner CLI moderation through `scripts/community_moderation.cjs` as documented in `firebase/COMMUNITY_MODERATION.md`; submission stays unavailable until that operation succeeds. When the deployed rule revision is unchanged and its tested deployment receipt is current, `bash scripts/release_ios.sh --upload-testflight` runs the source/release checks and signed QA archive/upload without another rule deployment.

## App Store Connect changes before App Review

- Update the age-rating questionnaire for **User-Generated Content** and **Messaging and Chat** (Apple's definition includes public posting), and retain the accurate advertising answer. Use Apple's calculated regional ratings and any necessary higher override; do not invent a universal age rating from a keyword filter.
- Review App Privacy for account identifiers, supplied name/email and **Other User Content** (comments, replies, private uploaded notes/library, reports), linked to the account for app functionality. A nickname does not de-identify the stored account UID. Keep the existing advertising/SDK disclosure review; do not copy the app-owned manifest as the complete vendor answer sheet.
- Public URLs: privacy.html, privacy-choices.html, terms.html, support.html, community.html and licenses.html on the existing Watchloom GitHub Pages site. Publish and verify the new pages before reviewer access. Bundled license notices remain available offline.
- Review notes should explain the pending moderation state, report/block/delete controls, series-only scope and optional account flow. Provide the reviewer with a working account or supported sign-in access as required; never post account credentials in source or public issues.
- TestFlight uses test ads. A later production archive needs production ad configuration and a fresh build number; owner performs the final App Review/live decision.

## Validation record

Source validation on November 6, 2026: 127 Flutter tests, 25 Python tests and 22 Node tests passed; Dart analysis and whitespace checks clean. The Flutter suite includes 19 live account-state cases covering Apple/Google/email trust resolution, verification refresh, sign-out/account switching, stale async results and draft disposal. The existing visual harness generated phone/tablet-size previews including 320 px at 180% text, with zero reported Flutter layout/exception errors. Cached official Firestore compiler validated rules syntax/types and all 13 literal RE2 patterns; these rules are unchanged by the build 8 UI/operator changes.

The full Auth/Firestore emulator authorization suite and rule deployment subsequently passed in the owner's Terminal. The local deployment receipt records success at 2026-11-06T06:04:55.321764+00:00; its rule hash matches the current source. The managed session cannot bind emulator ports (EPERM) or independently query Google APIs (ENOTFOUND), so remote results are identified as owner-run evidence. Apple/Google credential exchange, cross-user report/block/deletion behavior and App Store Connect processing still require device/console checks. A source commit does not prove TestFlight processing.

## Primary references

- [Apple App Review Guidelines, including 1.2](https://developer.apple.com/app-store/review/guidelines/)
- [Apple age-rating definitions](https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions/)
- [Apple App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/)
- [Apple privacy manifest data collection](https://developer.apple.com/documentation/bundleresources/describing-data-use-in-privacy-manifests)
- [Firestore security rules conditions](https://firebase.google.com/docs/firestore/security/rules-conditions)

This record describes implementation and release checks. It does not certify compliance with every country's law or guarantee the absence of bugs.

## Provider-independent owner moderation

The owner selected human approval before publication. All Apple, Google and verified email/password accounts share the same filtered, pending-only submission flow. Publisher moderation is configured with `node scripts/community_moderation.cjs init-owner --accept-moderation-responsibility`, using existing Google Cloud CLI/IAM access rather than requiring a matching app Auth email/UID. Optional UID-based moderator assignment remains available. Owner CLI mode does not give app users approval or private-report access. The operator helper rejects example UID placeholders before remote access and supports optional `init --email EMAIL` resolution to a unique existing, enabled and verified Auth UID. Neither initialization flow creates an app account.

The owner confirmed `init-owner` completed and provided status showing configured/enabled/moderationReady=true, rulesVersion=1, operatorType=owner-cli and ownerCliModeration=true. Community submission is enabled according to that owner Terminal output; publication still requires explicit operator approval. The managed session has not independently reread remote configuration.

Community pages now follow live account verification and provider changes, including email verification while the account screen covers the page. A UID change binds a new repository and clears the previous account's private identity, pending comments, block list and draft. Late results from a previous session cannot update the new session. These UI changes require build 8; the server activation itself already applies to the uploaded build 7 after reopening community.

## Binary delivery

The owner confirmed the QA upload command completed for 1.2.0 (7). Build 8 is a separate source revision for the live account-state fix above; its archive/upload completion must be recorded separately. App Store Connect processing and real-device behavior remain owner checks. TestFlight is not an App Review submission.

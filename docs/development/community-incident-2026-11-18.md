# Community authorization follow-up — 2026-11-18

## Confirmed observations

- Read-only production checks targeted `watchloom-canturhan` only. The released Firestore rules exactly matched the source at `c0efaee` before this change.
- All three existing community profiles had an active user root, current policy consent, valid posting counters and a verified email. No deletion marker or disabled/missing Auth account was found. These aggregate checks do not identify the reporting user's account or prove their current token claims.
- Six sampled comments were approved; none were pending/rejected. One legacy comment lacked `editRevision`, for which the existing code and rules already use revision zero.
- The user's exact old error wording exists before commit `294e728`, not in the current source. Confirm their installed version/build and failure operation before attributing their incident to a single cause. App Store Connect currently reports public version `1.0.6`, build `16`; this alone does not establish which source revision was installed on their device.
- Posting and editing share a server-enforced 30-second cooldown and 20 submissions per rolling day. These denials previously appeared as generic authorization failures. The provider matrix resets cooldowns in emulator setup; it does not prove an immediate edit is allowed.
- Session preparation was cached with bootstrap for the repository lifetime. A cached repository did not explicitly refresh verification/token claims for subsequent writes.
- Editing a legacy comment retained its old `policyVersion`; the moderation worker rejects a non-current policy. This is a separate compatibility defect, not proof of the reported permission denial.

## Changes

- Refresh the UID-bound session before profile consent writes, new comments/replies, owner edits/deletes, reports and votes. Keep bootstrap caching and deletion protection; never auto-merge UIDs or modify backups.
- Distinguish fixed diagnostic operations such as `post.profileRead`, `post.parentRead`, `post.commit`, `editComment.commentRead` and `editComment.commit`. Log only operation, SDK code and a bounded failure enum. Preserve SDK retries for transient transaction reads.
- After both definitively denied atomic counter proposals, give rate-limit feedback when the observed counter/cooldown supports it. This uses device time only for explaining an already rejected write; it never grants access or blocks a write before server evaluation. Wrong/ambiguous clocks retain the generic denial.
- Owner edits submit the current policy version and return to `pending`. Rules allow that one additional field only when equal to the current version. Ownership, revision checks, immutable identity/content/votes, counters, rate limits and server-only publication remain enforced.
- Rejected comments in the owner's submissions show localized, actionable language/safety, contact-information or account feedback. Unknown server reasons use a safe generic message; raw reasons are never displayed. Feedback is shown when submissions load/refresh, not sent as a push notification.
- Existing server moderation already rechecks edits, rejects inappropriate text, retries provider failures without publishing, and refuses stale revision verdicts. No worker code or production configuration was changed.

## Validation and rollout

Run `flutter test --no-pub`, `flutter analyze`, `bash scripts/deploy_firebase.sh --check`, and `node --test server/community-worker/test/*.test.mjs scripts/community_moderation_test.cjs`.

Final results on 2026-11-18: 233 Flutter tests passed; `flutter analyze` reported no issues; 28 Auth/Firestore emulator tests passed; 36 server/moderation tests passed; `git diff --check` passed. The first new test run exposed missing fields in the test double; these were corrected before the successful final suite. No production writes were used to run these tests.

The emulator matrix covers Apple/Google/verified-password claims for movies and series, expired consent and renewal, legacy comments, forbidden policy versions, owner-only editing/deletion, unpublished pending edits, and vote preservation. Other tests cover unverified/anonymous accounts, bootstrap of old Auth accounts, cooldowns/daily limits, moderation rejection, privacy and account switching. Emulator claims do not replace real-device provider sign-in tests.

No production deploy, account/data migration, outgoing email, Git push or new build upload was performed. After reviewing the changes:

1. Deploy the tested Firestore rule/index revision using `bash scripts/deploy_firebase.sh --deploy` from this repository. Deploy rules before distributing the new client, since legacy policy upgrades require the new narrow edit allowance. No worker deploy is needed for this change.
2. Build/distribute the updated iOS app and verify actual Apple, Google and verified-email accounts on device. Confirm current consent survives reinstall with the same UID; wait at least 30 seconds between submission/edit tests. Confirm owner changes are pending until moderation, rejected text is actionable, other-user edits/deletes fail, and votes/backups still work.
3. If the reporting user still fails, collect only installed version/build and the fixed operation/code log. Distinguish profile/bootstrap/read/commit failures; don't request tokens, UID, email, action links or comment bodies in logs. Different providers may represent different UIDs; link credentials only after authenticating the existing account and explicitly confirming ownership. Do not auto-merge accounts.

## Verification email branding

Read-only checks still show Firebase project display name `Watchloom`, default sender names, and `%APP_NAME%` in verification/reset/email-change templates. The old project string is not hardcoded in these templates. This does not prove that a newly delivered email resolves the placeholder correctly; no email was sent.

Complete the existing [authentication branding checklist](auth-branding.md): set sender display name to `Watchloom`, check the public-facing/OAuth app name is published as `Watchloom`, and test a new verification email using an owner-controlled account. Preserve `%LINK%`, locale behavior, action URL, sending address, SMTP settings and security. These console branding changes require no app build. See the [Firebase template documentation](https://support.google.com/firebase/answer/7000714?hl=en).

## Changed files

- `lib/features/community/data/firestore_community_repository.dart`
- `lib/features/community/domain/community_submission.dart`
- `lib/features/community/presentation/community_page.dart`
- `lib/features/community/presentation/community_strings.dart`
- `firebase/firestore.rules`
- `firebase/tests/community.test.cjs`
- `test/community_submission_test.dart`
- `test/community_repository_submission_test.dart`
- `test/community_rejection_feedback_test.dart`
- `test/community_presentation_test.dart`
- `docs/development/community-incident-2026-11-18.md`

## Follow-up: authorized email update and upgrade preservation

After the original community review, the owner explicitly requested and
authorized the live email branding fix. The earlier statement that no
production configuration was changed applies to the community investigation;
the following narrowly scoped Auth email change has now been applied.

- Firebase Console showed **Public-facing name: Watchloom**, independently of
  the project's display name.
- `scripts/configure_auth_email_branding.cjs --apply` changed only sender
  display names in verification, reset-password and email-change templates to
  `Watchloom`. The script uses a field mask and verified that protected Auth
  configuration was unchanged. A separate `--check` returned no pending changes.
- No email was sent; resolved placeholder/inbox rendering still requires a
  new verification email through the normal owner-controlled app flow. OAuth
  notification branding remains a separate Google setting.
- No Firestore rules, worker, user records or backups were deployed/mutated.
- App upgrade retains bundle ID `com.canturhan.watchloom`, guest filename
  `watchloom.db`, stable UID-derived account filenames and schema version 6.
  Database, account-session and backup code are unchanged by this fix.
  Startup does not erase a library as part of an app version upgrade.
- Six SQLite storage tests passed. The expanded legacy migration test checks
  notes, favorites, watch history, achievements and backup revision/dirty
  markers; a new real-file reopen test preserves both series/movie records
  and all associated rows. `node --check` for the branding script and
  `git diff --check` also passed. The Flutter source still matches the
  successful 233-test/static-analysis run above.
- A physical-device install-over-existing-version test has not been run in
  this task. Before release, record sample series/movie progress and notes in
  the old installation, install the new build as an update without uninstalling,
  and confirm the same guest/account library and backup status. Different UIDs
  intentionally select separate libraries; do not auto-merge them.

Additional changed files in this follow-up:

- `scripts/configure_auth_email_branding.cjs`
- `scripts/test_account_storage.py`
- `docs/development/auth-branding.md`

## Final continuation: authorized rules deployment and local iOS build

The owner confirmed the delivered test email shows `Watchloom`, asked to
continue the comment/data-preservation work and explicitly granted all
permissions for the fix. On that renewed authorization:

- Deployed current Firestore rules/indexes to `watchloom-canturhan` with
  `bash scripts/deploy_firebase.sh --deploy`. The script reran all 28 local
  Auth/Firestore rule tests, checked Spark, and confirmed the tested rule
  receipt and denied anonymous private-account reads. No users, comments,
  votes or backups were deleted or reset.
- A read-only preflight found zero comment/report changes needed for the
  new rule hash. Renewed the automation compatibility receipt with the
  existing migration command: **0 documents updated** (only its administrative
  receipt was renewed). No existing scores or consent were rewritten.
- Updated app source version to **1.2.6+17**. A local unsigned release build
  completed successfully (`build/ios/iphoneos/Runner.app`, 74.3 MB).
  Independently checked bundle ID `com.canturhan.watchloom`, app version
  `1.2.6`, build `17`, installed Pods and actual compiled Firebase resources.
  The build used test ads and was not archived, signed, uploaded or distributed.
- Expanded release checks passed: **34 Python tests**, **64 Node tests**,
  and Cloudflare `workerd` runtime tests. Existing Flutter checks remain
  **233 tests passed** and clean static analysis; no Flutter implementation
  changed after those checks, only the package version.
- Public Worker network checks still fail on this network with `EPROTO` /
  `CURL_35`, including certificate-verified connections to addresses obtained
  from two independent encrypted DNS providers. No certificate validation was
  disabled and no system DNS/proxy configuration was changed. This is separate
  from Firestore authorization; final live moderation readiness cannot be
  claimed from successful synthetic tests or the native build.

Release remains pending a successful live moderation health check and actual
provider/device QA. Verify the new build over an existing installation without
uninstalling; check sample series/movie progress, notes, favorites and history,
then create, edit, reject/revise and delete owner comments using Apple, Google
and verified email accounts. Retain the current 30-second/20-per-day limits and
verify other-user edits/deletes remain denied. A successful local unsigned
compile is not a TestFlight upload or proof that other users have the fix yet.

Additional changed file: `pubspec.yaml`.

## Sonraki kuyruk doğrulaması

Kullanıcının aynı bağlantıdan devam etme isteği üzerine istemci HTTP hızlandırma
çağrısı arka plana alındı ve kendi gönderileri için canlı Firestore dinleyicisi
eklendi. Yayımlanan Worker'ın gerçek cron'u üzerinden nonce'a bağlı yönetici
kontrolü Firebase/Auth/index ve sentetik moderasyonu başarıyla doğruladı.
Doğrudan TLS hâlâ ağda başarısız; bu sonuç onu gizlemez veya sertifika
doğrulamasını gevşetmez. Güncel mimari, canlı yayın ve testler için
[Worker TLS / kuyruk raporuna](community-worker-tls.md) bakın.

Güncel sonuçlar: 235 Flutter, 73 Node, 34 Python, 28 emülatör testi başarılı;
Flutter analiz temiz; yeni kaynakla 1.2.6 (17) iOS derlemesi başarılı. Gerçek
kullanıcı/provider cihaz testi henüz yapılmadı. Sonraki adımda **1.2.6 (17)
TestFlight'a yüklendi**; Apple `VALID / READY_FOR_BETA_TESTING` olarak işledi.
[Yükleme kaydı ve son cihaz kontrolü](testflight-1.2.6.md).

# Watchloom community operations (Spark)

Public series comments are premoderated. A verified account chooses a public
handle and optionally a nickname, explicitly accepts policy version `2026-11-05`,
and submits a pending comment. Firebase email, legal name and provider display name
are never copied to a community identity. A moderator reviews both the chosen
public name and the text before publication. Replies are one level deep and can
only address an approved root in the same `tvmaze:show:<positive integer>` series.
Films are outside this release.

## Before any public posting

1. Run the Auth + Firestore emulator suite from a normal Mac Terminal. A sandbox
   may deny loopback sockets; that is not a test pass. Deploy the tested rules and
   indexes with `bash scripts/deploy_firebase.sh --deploy` and keep its successful
   deployment receipt. Do not initialize moderation before the suite passes.
2. Verify public privacy, terms/community guidelines and support/contact pages are
   available; review the App Store privacy answers and age/content rating.
3. The publisher signs in to the Firebase CLI using an authorized Google Cloud
   account for this project. Owner-operated CLI moderation does not require a
   separate Watchloom app account or a matching Apple/Google/email address.
   Normal participants can use Apple, Google or a verified email/password account;
   all use the same private profile, filter and pending-comment workflow.
4. A real operator accepts responsibility for checking pending comments and
   reports daily, responding to harmful-content reports promptly (target within
   24 hours), and disabling posting while coverage is unavailable. This is an
   operational obligation, not an automated service or response-time guarantee.
5. In the owner's Mac Terminal, using the existing Firebase CLI owner login:

   ```sh
   node scripts/community_moderation.cjs init-owner --accept-moderation-responsibility
   node scripts/community_moderation.cjs status
   ```

   `init-owner` uses the existing owner CLI OAuth/IAM permissions to atomically
   create readiness configuration. It does not create a Firebase Auth account,
   grant an app user administrative rights, or bypass pending-only submission.
   Each moderation API operation still requires the owner’s Cloud IAM access.

   Optionally, to assign an existing verified Watchloom app account as a moderator
   instead, use its actual UID with `init FIREBASE_UID`, or resolve it by email:

   ```sh
   node scripts/community_moderation.cjs init --email YOUR_WATCHLOOM_EMAIL --accept-moderation-responsibility
   ```

   `FIREBASE_UID` and `YOUR_WATCHLOOM_EMAIL` above are placeholders. Email lookup
   runs only under the owner's CLI credentials and must return exactly one
   enabled, verified Auth account; it does not create an account or grant a role
   based on an app-supplied email. The stored role always uses the verified UID.
   Sign in to Watchloom first. Apple Hide My Email may require the Auth UID
   instead of your personal email address.

   The optional `init` account flow verifies the UID against Firebase
   Authentication, then atomically creates its server-managed role and readiness
   configuration. The default `init-owner` flow needs no app UID. The app cannot grant
   roles or enable itself. Nothing is automatically initialized by installation,
   account creation, deploy or client-side configuration. This script is pinned
   to `watchloom-canturhan` and refuses linked/active billing using the existing
   Spark guard. It never enables billing, Functions, paid TTL or scheduled jobs.

## Daily owner workflow

```sh
node scripts/community_moderation.cjs pending
node scripts/community_moderation.cjs reports
node scripts/community_moderation.cjs approve COMMENT_ID --reason acceptable
node scripts/community_moderation.cjs reject COMMENT_ID --reason abuse
node scripts/community_moderation.cjs remove COMMENT_ID --reason personalInformation
node scripts/community_moderation.cjs resolve-report REPORT_ID --reason actioned
node scripts/community_moderation.cjs maintenance
```

Queue output is private moderation material. Keep it in the operator's local
Terminal; do not paste bodies or reporter identities into public GitHub issues,
analytics, review notes or chats. Pages contain at most 50 items. Continue using
`pending --cursor VALUE` or `reports --cursor VALUE` until `nextCursor` is null.
Moderators must consider profanity, hate, threats, harassment, sexual/illegal
content, personal information, impersonation, spam and spoilers, including
obfuscated spellings and image-like Unicode sequences. Accepting text through a
filter does not establish that it is acceptable. Mark spoiler content or reject
misleading spoiler-free submissions. Rejected text remains visible only to its
author and the moderator; removal deletes the text completely. No published
comment can be edited directly by a client; a replacement is a new pending post.

The CLI's owner IAM permissions authorize moderation, not a client role document.
Role records identify accountable verified operators and allow private queue
access in the security rules when app-moderator mode is selected. Owner CLI mode
keeps reports accessible only through authorized IAM operations. Granting a UID
does not grant Google Cloud IAM or
permission to run the CLI with another person's credentials. There is no app
admin key, service-account JSON or OAuth token bundled in Watchloom. Do not print
Firebase CLI debug logs during private operations. The helper suppresses API
request/response body logging and prints no OAuth data.

Approval rechecks the author's active root, current policy consent, Auth account,
deletion marker and operational configuration. In the optional app-moderator
mode it also verifies the primary moderator's Auth identity; owner CLI mode
requires Cloud IAM permission on every operation. Reply approval
also rechecks the root and mutual block/deletion state; a block made while a reply
was pending continues to prevent contact. Delete/reject harmful published content,
resolve associated reports, and disable persistent abusive Firebase Auth accounts
in Firebase Console. Existing ID tokens may remain valid briefly, but cannot
publish anything without new owner approval. The support address is an alternate
abuse/report and account-deletion channel.

Pause immediately if a queue cannot be reviewed or an abuse/quota incident occurs:

```sh
node scripts/community_moderation.cjs pause
node scripts/community_moderation.cjs resume --accept-moderation-responsibility
```

Pause disables new comments and approvals. Reports, blocking, own-comment deletion
and account deletion remain available. Revoking the primary moderator atomically
pauses posting and clears readiness. To replace a revoked/deleted primary:

```sh
node scripts/community_moderation.cjs grant NEW_FIREBASE_UID
node scripts/community_moderation.cjs set-primary NEW_FIREBASE_UID --accept-moderation-responsibility
node scripts/community_moderation.cjs resume --accept-moderation-responsibility
```

`set-primary` verifies the account and prepares readiness while leaving posting
paused. Use `revoke FIREBASE_UID` for departed operators.

## Data and deletion

- `communityProfiles/{uid}` is private and stores the chosen identity, consent
  version/time and submission counters. `communityHandles/{handle}` is an atomic
  unique reservation, not a public UID directory. Handles are stable until account
  deletion; nicknames/display mode may change after renewed explicit consent.
- `communityComments/{id}` contains series key, random author UID, the chosen
  public-name snapshot, body, spoiler flag, nullable root ID, status and timestamps.
  Only approved comments are public. Authors see their pending/rejected text;
  operators see the moderation queue. Public queries are bounded to 50 comments.
- `communityReports/{id}` contains only comment ID, reporter UID, reason enum and
  creation time. It does **not** copy the reported text/name/target-author UID.
  Only moderators can read reports, including the reporter's own report. Private
  `users/{uid}/communityReportRefs/{id}` pointers permit blind account cleanup.
  Resolution atomically removes report and pointer. Account deletion removes all
  reports made by that account even if not yet resolved.
- `communityBlocks/{uid}/authors/{blockedUid}` is private. The app suppresses
  blocked authors and rules reject replies between blocked participants in either
  direction. Approved comments remain publicly accessible to guests and through
  other accounts; blocking is not a confidentiality/access-control boundary.
- Account deletion first acquires the existing fresh-auth replay lock, then
  removes snapshots, all owned comments, own reports/pointers and own block list,
  then atomically removes identity and handle, and only then removes root/Auth.
  Failed cleanup leaves Auth intact and is retryable after reauthentication.
  Old v6 clients are denied root purge while a community profile exists; they must
  update to finish deletion, preventing old code from stranding public comments.
  Other authors' replies survive independently; the UI displays an unavailable
  parent placeholder without retaining deleted body/name/UID in a tombstone.
  A private block preference owned by another user may retain only a random
  deleted UID; this reveals no email, profile or text and is not a public record.
  For a support-requested administrative cleanup, run
  `node scripts/community_moderation.cjs purge-deleted DELETED_FIREBASE_UID`.
  The helper verifies Auth no longer contains that UID, then removes incoming
  preferences in bounded pages without exposing block owners. It refuses an
  unexpected collection-group path and cannot be used on a live Auth account.
- Minimal owner-only moderation events contain action, target random ID, reason,
  source and time, with no comment/name/report snapshots. Configuration actions
  may identify a moderator UID. They are not client-readable.

`maintenance` manually removes pending/rejected comments older than 30 days and
reports/moderation events older than 90 days; report pointers are removed with
reports. These are **manual operator retention limits**, not automatic TTL or a
scheduled backend. Run it daily and record completion privately; pause posting if
this cannot be maintained. Authors can delete their own comments sooner, and
account deletion does not wait for maintenance.

## Security and Spark limits

Every client comment is `pending`. No client or moderator-authenticated app can
set approval, change authorship or inject trust/Premium fields. Ordinary app
accounts cannot read private reports; explicitly assigned moderator roles may
read moderation data as allowed by the rules. Owner CLI initialization creates no
such app role. Owner moderation bypasses client rules via scoped existing CLI OAuth;
protect the owner Google account/IAM and use multi-factor authentication.

Firestore uses request.time to enforce a 30-second comment cooldown and 20 posts
per rolling 24-hour window; reports use 60 seconds and 5 per window. The repository
proposes one counter window then tries the alternate after a definitively denied
atomic write, retaining the same document ID. Device time is only a proposal;
network/unknown-commit errors are never replayed as a new submission. Security
rule permission-denied responses cannot reliably distinguish rate, verification,
block and policy failures; the UI must not promise a precise server retry time.

Unicode letter/mark/number/punctuation/symbol categories permit international text
and emoji while excluding format/bidi/control codepoints. Client text composition
and a small rules word list catch common abuse/contacts, not all languages,
normalization tricks, context or PII. **Manual premoderation is the publication
boundary.** Firestore rules cannot run comprehensive Unicode moderation, external
reputation, ML classification or global anti-Sybil controls. Verified accounts and
per-UID limits do not stop a determined attacker using many verified accounts.

App Check enforcement is not enabled by this change. App Check can reduce
unauthorized-client traffic after genuine device attestation is integrated/tested;
it cannot replace auth, rules, moderation or rate limits. Spark quotas can stop
reads/writes, including reporting/account cleanup until service recovers. No
automatic scaling or uptime guarantee is claimed and no linked billing is added.
Watch Firebase usage and moderation capacity; keep posting disabled until these
limits and the real operator workflow are acceptable. Public-release readiness
requires normal-Terminal emulator tests, verified deployed rules/indexes/config,
real-device cross-user/report/block/deletion tests and owner review of policies.

# Watchloom community operations

Current release uses automatic server moderation. See [COMMUNITY_AUTOMATION.md](COMMUNITY_AUTOMATION.md) for architecture, explicit user consent, free-tier setup, retries, votes, retention and release checks. Routine comments do not require owner approval.

Apple, Google and verified email/password participants use the same flow. The owner CLI uses existing Google Cloud IAM, so the publisher does not need a matching Watchloom Auth email or UID.

## Monitoring and emergency controls

```sh
node scripts/community_moderation.cjs status
node scripts/community_moderation.cjs pause
node scripts/community_moderation.cjs resume --accept-moderation-responsibility
```

Pausing stops new submissions and publication. Reporting, blocks, own deletion and account deletion remain available. Automatic report rechecks may still remove harmful existing content while posting is paused. Do not resume if the Worker/provider, quota, consent or deployed rules are not ready.

The status should show rulesVersion 2 and moderationMode automatic after verified setup. Readiness configuration does not itself prove provider uptime or an empty report queue. Monitor Firebase/Cloudflare usage and service failures, and maintain the published support address for appeals, rights/deletion requests and urgent safety concerns. Automation cannot guarantee perfect judgments or replace publisher accountability.

For a support/safety exception:

```sh
node scripts/community_moderation.cjs pending
node scripts/community_moderation.cjs reports
node scripts/community_moderation.cjs remove COMMENT_ID --reason personalInformation
node scripts/community_moderation.cjs reject COMMENT_ID --reason abuse
node scripts/community_moderation.cjs resolve-report REPORT_ID --reason actioned
```

COMMENT_ID and REPORT_ID are placeholders for the actual returned IDs. These optional emergency commands do not form the routine publication workflow. Manual approve is disabled in automatic mode. Removing an approved comment deletes its content; hiding it must preserve its existing vote counters. Never reset voted counters to zero while private choices still exist.

Queues and reports are private material. Keep text and identities in the owner's Terminal; do not paste them into public GitHub issues, analytics or chats. Continue bounded pages using pending --cursor VALUE or reports --cursor VALUE when nextCursor is present. The helper suppresses API request/response-body and token logging. No admin key is bundled in the app.

## Deletion and retention

Account deletion locks writes, withdraws the account's votes with paired aggregate/count updates, removes authored content and its private identity/reports/blocks, then deletes Auth. A profile with outstanding votes cannot be deleted by an older client. Missing/hidden targets remain removable during vote cleanup. Other people's independent replies survive without a deleted parent's body/name snapshot.

Another account's private block preference can retain only a random deleted UID. Administrative support cleanup:

```sh
node scripts/community_moderation.cjs purge-deleted DELETED_FIREBASE_UID
```

Use the actual deleted UID. The helper verifies Auth absence and refuses an unexpected collection path or a live account.

The Worker runs bounded retention jobs automatically: pending/rejected posts and processing jobs after 30 days; reports and minimal moderation events after 90 days. Provider outages, quotas or a specific legal/safety obligation can delay cleanup. The existing maintenance command remains an optional owner recovery tool.

## Legacy configuration

init-owner and init --email are compatibility commands for the earlier manual workflow. Do not run them to configure this automatic release. They cannot reset an already configured project. Optional grant/revoke/set-primary manage legacy app moderator roles; assigning a role never grants Google Cloud IAM. Normal users cannot enable posting, grant roles or approve text.

No billing link, Firebase Functions deployment, paid TTL/scheduler or Blaze upgrade is authorized by these commands. Protect the publisher's Google account and dedicated server secrets, and keep deployment/device evidence separate from source test results.

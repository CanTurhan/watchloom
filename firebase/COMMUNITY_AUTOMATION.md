# Automatic Watchloom community

The owner selected automatic safety checks and publication on November 6, 2026.
This replaces per-comment manual approval. Watchloom remains on Firebase Spark;
Puzzle Music Sort is a separate project and receives none of these credentials.

## Flow

1. A verified Apple/Google/email account explicitly accepts policy
   `2026-11-06-auto-v1`. The notice names Cloudflare and OpenAI and explains the
   data sent to each. Existing consent is not silently upgraded.
2. A Firestore transaction stores a **pending** series comment and advances the
   existing server-enforced 30-second/20-per-window submission counter. The client
   cannot approve itself or supply a moderation result.
3. An authenticated request wakes the Cloudflare Worker using only a comment ID.
   It verifies the Firebase JWT signature, issuer/audience, expiry, Auth revocation
   and disabled state. The requester must own that pending comment.
4. The Worker claims an expiring job lease, reserves a daily allowance, checks
   account/deletion/consent/parent/block state and validates text/public label.
   OpenAI receives **only body and public label**, not a UID, email, library or
   watch history. Local rules handle common obfuscated profanity, threats,
   controls/links/contact details. The free Moderations endpoint classifies both
   inputs for harm categories. This is a classifier, not a prompted text generator.
5. A second transaction rechecks the live account and submission. Allowed content
   becomes approved; unsafe content becomes rejected. Provider errors, timeouts,
   malformed classifications, quota failures and config pauses never publish.
6. A minute Cron trigger retries eligible pending jobs with backoff. Every third
   minute prioritizes a reported comment for a fresh check; a harmful result hides
   it, a spoiler report can add the spoiler flag, and private report/pointer records
   are removed atomically on completion. Legacy text is not sent to AI without
   consent. A support/appeal contact remains available; automatic classification
   cannot guarantee correct handling of every report or legal request.

Per-invocation work is bounded to one moderation job, below Workers Free's 50
subrequest limit. Scheduled cleanup runs separately every ten minutes, rotating
small batches: pending/rejected posts and processing jobs after 30 days,
reports/events after 90 days, daily budget records after 30 days. Preconditions
prevent maintenance from deleting a concurrently approved or changed post.
Service outages can delay these operational retention targets.

## Pricing and credentials

No Firebase upgrade, Functions, paid Cloud Run/queues/TTL, D1 or Workers AI is
configured. Workers Free currently includes 100,000 requests/day and 10 ms CPU per
invocation; exceeding a free quota can stop service. OpenAI's Moderation endpoint
is currently free, with account-specific rate limits. The initial automation cap
is **500 moderation/recheck jobs per UTC day**, shared by immediate requests and
Cron, with the last 50 reserved for reports. New submissions wait after 450 jobs
have been consumed, leaving report capacity. A job beyond the cap
remains pending. This cap is not a guarantee against quota exhaustion from other
Firestore activity, votes or abusive traffic. No paid fallback is used.

The publisher's account must have actual API access; a ChatGPT subscription alone
is not an API credential. Keep OpenAI data-sharing/training opt-in disabled for
this project. The key should be restricted to Moderations where available.

Secrets live only at `~/.config/watchloom/community/worker-secrets.json` (0600,
private directory 0700) and in encrypted Cloudflare Worker secret bindings.
`OPENAI_API_KEY`, `FIREBASE_SERVICE_ACCOUNT` and `SETUP_TOKEN` never enter Dart,
assets, Git, URLs or app build arguments. The dedicated Google identity has only
Firestore data access and Firebase Auth read access, with no billing, project
administration or Auth write role. Firestore IAM is broader than collection
rules; protect and rotate this server credential, which can access database data.
Worker code exposes only fixed moderation/setup routes and pins the project.
Full request/body/provider-output logs and Worker observability are disabled.
Cloudflare still necessarily processes network metadata and the Firebase token,
which may contain account email claims; the policy explicitly discloses this.

## Initial setup in the owner's normal Terminal

The owner has authorized this automatic architecture. The responsibility flag
below records that choice; it is not a request to approve individual comments.

```sh
cd /Users/canturhan/CodingSpace/watchloom
npx --yes wrangler@4.158.0 login
python3 scripts/set_community_api_key.py
bash scripts/setup_community_automation.sh --deploy
```

The first two steps are one-time setup; do not repeat a completed login/key entry.
After they are complete, `bash scripts/ship_testflight.sh` combines the verified
server setup with the signed QA build/TestFlight upload and stops on any failure.
Cloudflare dashboard login and CLI OAuth authorization are separate. Complete the
CLI browser Allow/Authorize flow and confirm `wrangler whoami` shows the intended
Free account. Do not use a temporary preview account for production.

On a new Cloudflare account, the first deployment asks to register an account
workers.dev subdomain. Answer yes and enter an available name (for example,
watchloom-canturhan); this is a one-time namespace registration. The setup script
preserves the Terminal for those prompts and reads the resulting endpoint from
Wrangler's separate structured deployment receipt. It never infers success from
an error message or an old console URL. Initial subdomain DNS can take a few
minutes to propagate before the protected health check succeeds.
This uses [Wrangler's supported ND-JSON output](https://developers.cloudflare.com/changelog/post/2025-11-03-wrangler-output-file/)
while preserving the CLI's interactive Terminal prompts.

The deployment script runs server tests and the Auth/Firestore emulator suite,
checks Spark billing remains unlinked, deploys current rules/indexes, provisions
the dedicated IAM identity/key if missing, migrates legacy ranking fields without
resetting existing votes, deploys the stable named Worker and binds secrets. Old
pending posts without AI consent are rejected with a resubmission reason; their
text is not sent to OpenAI. It then verifies live AI access, Auth/Firestore IAM and
the required indexes through a secret-protected synthetic setup check before
enabling/read-back of rulesVersion 2 automatic mode. Index construction or IAM
propagation can temporarily prevent activation; rerunning is idempotent and does
not mint another key when one is already present.

No setup phase may be called complete solely from a source commit or local unit
test. If rules change, the previous deployment receipt becomes invalid. The
managed Codex session has restricted Google API/localhost access; owner Terminal
results must be distinguished from independent verification.

## Diagnosing a deployed Worker

If activation stops after the Worker and secret bindings are published, do not
re-enter keys or repeat deployment before identifying the failing layer. The
owner can run:

```sh
node scripts/diagnose_worker_network.mjs https://watchloom-community.watchloom-canturhan.workers.dev
node scripts/diagnose_community_automation.mjs https://watchloom-community.watchloom-canturhan.workers.dev
```

The first command reads no application credentials. It separately checks DNS,
certificate-verified TLS, native HTTPS with the default and an independent agent,
Node's fetch and macOS curl with default and HTTP/1.1 negotiation. A failed HTTP
probe does not stop the remaining comparisons. It reports runtime versions,
known proxy variable names and booleans, never their values. Network details are
bounded and redacted, without response bodies or redirect locations. It never
disables certificate checks or follows authentication redirects. The independent
agent is diagnostic only and does not change deployment or app transport.

The second command reads the existing private configuration, checks the
protected deployed setup endpoint, then isolates Google OAuth, Auth lookup,
pending/ranking indexes and synthetic OpenAI classification if needed. Only
fixed stage names, HTTP status and whitelisted error codes are printed. It does
not enable automatic mode, publish comments or manufacture a Worker health proof.
Passing dependencies from the owner's Mac does not prove the deployed Worker can
reach them. Activation and release still require the protected live check.

The protected setup response identifies exactly one failed check:
`server_credentials`, `google_oauth`, `firebase_auth`, `pending_index`,
`ranking_index`, `openai_moderation` or `health_write`. After verifying the owner
setup token, it may return a whitelisted provider code and numeric upstream HTTP
status. Provider messages, request/response bodies, tokens, emails and key data
are never returned or logged. The owner client validates the project/policy/
release and stage/code vocabulary before printing these diagnostics. Anonymous
or invalid-token requests receive no setup details, including when server
credentials are malformed. Health proof creation follows all provider checks;
the client still requires both a successful response and the fresh stored proof.

An HTTP 503 after the native HTTPS correction is not sufficient to name the
failing provider. Publish the current Worker diagnostics with the complete
shipping entry point, which then checks activation and stops on failure:

```sh
bash scripts/ship_testflight.sh
```

The final `Check:` value and provider code identify the failing live step. Do not
repeat key entry, change billing or skip health verification based on a generic
503. The managed session cannot refresh Cloudflare OAuth because it cannot reach
that auth server; this does not invalidate the owner's existing CLI login.

On the owner's Node 25.2.0/OpenSSL 3.6.3 runtime, native HTTPS and both curl
probes returned the correct health response with HTTP 200 while fetch failed
with a TLS record error; no proxy variables were present. The protected setup
check therefore uses native HTTPS in both activation and release tooling.
Certificate verification stays enabled, redirects are rejected, responses are
limited to 64 KiB and identity/policy/release must match exactly. One transient
connection/protocol retry is permitted within the same 45-second deadline;
certificate, HTTP and invalid-response failures never retry or enable posting.
The protected provider check and its fresh Firestore proof remain mandatory.

After current rules/indexes, migration, the stable Worker and its three secrets
have already been deployed, continue without redeploying them:

```sh
bash scripts/ship_testflight.sh --resume
```

This explicitly activates the already deployed automatic community only after
the current rule/migration receipts and real provider/IAM/index health pass.
It then runs the complete release checks, builds the signed QA archive and uploads
it to TestFlight. Any failure stops the sequence; the normal release check by
itself still never enables a paused community.

Both setup and release checks include twelve synthetic scenarios executed by the
pinned Wrangler dependency's `workerd` runtime. They exercise production setup,
RSA key import/signing, stream/JSON processing, each provider failure, proof
creation and owner-only diagnostics. Test keys are generated in memory and real
network access is blocked. Run them independently with:

```sh
bash scripts/test_worker_runtime.sh
```

These checks cover runtime behavior; they cannot prove live credentials, IAM,
provider availability, Cloudflare platform quotas or production CPU usage.

The live `google_oauth / OUTBOUND_NETWORK_ERROR` was reproduced by constructing
an actual workerd Request before synthetic responses. Workers rejects
`redirect: 'error'` before sending a request. Both provider JSON requests and
Firestore requests now use `redirect: 'manual'` and reject non-2xx responses;
credentials cannot follow a redirect. The original fixture skipped Request
construction and missed this incompatibility. The corrected fixture failed
before the fix and passed afterward, including OAuth/Firestore/OpenAI redirect
rejection. See the [Cloudflare Request reference](https://developers.cloudflare.com/workers/runtime-apis/request/).

## Votes and ranking

An approved comment has integer `upVotes`, `downVotes`, `score = upVotes-downVotes`
and `scoreSchema=1`. Best-first is a server-indexed query, then creation time
descending for ties; newest-first remains available. Replies stay under their
root. The bounded feed is a page, not a promise to load every historical reply.

The private single choice is `users/{uid}/communityVotes/{commentId}`. A new vote
transaction reads profile/comment/old vote, then atomically changes the public
totals, private choice and profile vote-count/last-vote fields. Rules require the
exact paired delta, current consent for new votes, a verified active account,
one-second cooldown, no self-vote and mutual block checks. A repeated choice
adds no score; selecting it again withdraws it. Switching +1 to -1 changes the
net score by two while preserving the number of voters. Counts are bounded and
cannot be directly incremented by a forged REST write.

Deleting an account first locks writes, withdraws its votes through the same
paired protocol, removes its authored content/reports/blocks/profile, then Auth.
The profile cannot be deleted while its vote count is nonzero, including from an
older app. Withdrawal reads only the private vote and profile and uses blind
counter transforms, without granting read access to rejected text. A definitive
missing/denied target write retries a counterless withdrawal; rules permit that
fallback only if the target is absent. Unknown network failures remain errors.
Withdrawal works for a hidden or already deleted target. Moderation
must preserve existing vote totals when hiding a post; resetting them strands
private votes and breaks deletion integrity. Removing the whole post is safe.

## Release and operational checks

Use source `1.2.0 (9)` on `version_1.1.0_6`. Older binaries cannot submit under the
new consent protocol. After successful server setup:

```sh
bash scripts/release_ios.sh --upload-testflight
```

The release helper verifies enabled automatic configuration, the current
migration proof and a fresh protected provider/IAM/index health check before any
archive/upload. It does not silently enable a paused community. A partially
completed server setup therefore cannot ship another closed-comment build.

Verify real-device Apple/Google/email sign-in and renewed consent, allowed and
prohibited Turkish/English text and names, provider outage/pending retry, two-user
up/down/switch/withdraw/order, no self-voting, report/block/spoilers, and deletion
with outstanding votes. App Review/live submission remains the owner's decision.
App Store privacy disclosures must include community content and the named AI
processing; report/block/contact and accurate UGC age-rating answers remain.
Automatic tools can make mistakes, and the publisher still owns safety/rights
responses. No zero-bug or universal legal-compliance certification is claimed.

Emergency controls are documented in [COMMUNITY_MODERATION.md](COMMUNITY_MODERATION.md).

## Official references checked November 6, 2026

- [Firebase plans](https://firebase.google.com/docs/projects/billing/firebase-pricing-plans)
- [Workers limits](https://developers.cloudflare.com/workers/platform/limits/)
- [Workers secrets](https://developers.cloudflare.com/workers/configuration/secrets/)
- [Node proxy configuration](https://nodejs.org/learn/http/enterprise-network-configuration)
- [OpenAI Moderation API](https://developers.openai.com/api/docs/guides/moderation)
- [OpenAI API data controls](https://developers.openai.com/api/docs/guides/your-data)
- [Apple guidelines 1.2 and 5.1.2](https://developer.apple.com/app-store/review/guidelines/)

# Watchloom 1.2.0 (9) — automatic community and voting

Delivery branch: version_1.1.0_6. Watchloom bundle com.canturhan.watchloom, Firebase watchloom-canturhan (Spark), repository CanTurhan/watchloom. Puzzle Music Sort remains a separate app, bundle, repository, version and Firebase project; no Watchloom key or data is reused.

## Result

Series comments use local text guards plus server safety classification before automatic publication. Per-comment manual approval is replaced by a Cloudflare Worker calling only the free OpenAI Moderation API. The app stores pending text; it cannot approve itself. Errors, malformed results, quotas and outages keep text unpublished and scheduled retries continue. New explicit consent names Cloudflare/OpenAI before content is sent. Existing consent is not silently upgraded.

Approved comments support one private up/down choice per verified account. Selecting the same direction withdraws it; changing direction updates the net score by two. Default best-first is a global indexed query with creation time breaking ties; newest-first is available. Replies remain threaded. Self-votes, forged counters, missing paired writes and mutual-block interactions are denied by rules. Profile, private vote and public totals update atomically.

Deletion withdraws outstanding votes before profile/Auth removal; older clients cannot strand votes by skipping cleanup. Hidden comments retain counters, and a deleted target is safe to clean. Live account verification/UID changes clear private profile, pending, blocks, votes and drafts; old async work cannot update the new session.

The earlier UI/theme, single profile settings action, hosted/offline licenses and monthly statistics fixes remain. This is series-only: no movie catalog or movie counters.

## Deployment

Read [automatic setup](firebase/COMMUNITY_AUTOMATION.md). One-time API key collection writes a private 0600 file outside the repository. The owner has confirmed key collection; a key format check does not prove API access. Cloudflare browser login and CLI OAuth are distinct.

After the one-time CLI authorization and private key setup, the complete owner Terminal entry point is `bash scripts/ship_testflight.sh`. It runs automatic community deployment first, then source/release checks, a signed QA archive and TestFlight upload, stopping at any failed phase. The stages can also be run separately:

```sh
bash scripts/setup_community_automation.sh --deploy
bash scripts/release_ios.sh --upload-testflight
```

Server setup enforces emulator-tested current rules, Spark billing verification, indexes, safe legacy ranking migration, a dedicated IAM identity, encrypted Worker secrets, a real synthetic provider/IAM/index check and activation read-back. The initial shared cap is 500 moderation/recheck jobs/day; free quotas can stop service and pending comments then wait. No paid fallback or billing upgrade is configured.

The release helper additionally verifies the enabled automatic config, current migration receipt and a fresh protected provider/IAM/index health check before archive/upload; a failed or incomplete server setup cannot produce another new closed-comment release. This check does not enable a paused community.

Version 1.2.0 (7) QA upload was owner-confirmed. Build 8 source was saved but its managed upload attempt stopped at live Firestore verification before archive creation. Build 9 contains this new automation/voting feature and must be built/uploaded separately. A source commit does not prove TestFlight processing. TestFlight uses test ads; production requires fresh production configuration/build and the owner's final review decision.

## App Store and privacy

Update App Store Connect UGC/Messaging and Chat/advertising age-rating answers and App Privacy to reflect community content, identifiers, private votes and the actual Cloudflare/OpenAI processing. Review all vendor SDK disclosures separately from the app-owned manifest.

Public privacy, terms, community guidelines, contact and software notices must match the in-app notices before reviewer access. Third-party AI data sharing is explicitly described and consented to under Apple 5.1.2. Reporting, blocking, own deletion and support/appeal contact remain available under 1.2. Automated tools can make mistakes; the publisher remains responsible for safety/rights requests.

Review notes should explain automatic checks, pending retries, rejected content, vote controls, optional accounts and series-only scope. Provide a supported reviewer sign-in path privately. Never include credentials in source or public issues.

## Validation and remaining evidence

Dart implementation: 158 Flutter tests passed and lib/test/tool analysis was clean. It includes auth-state, renewed-consent, HTTP/token-race, vote transition/transaction, hidden/deleted-target withdrawal, ranking/threading, busy/cooldown and large-text UI cases. The 47 Node tests and 32 Python tests passed, covering real RSA signature/claim/revocation checks with local keys, fail-closed moderation, consent/deletion/block races, preserved migrated totals, private secret-file handling, report queue backoff/reserved quota, strict health proof validation, structured Worker deployment receipts and credential-safe diagnostics. Wrangler 4.158.0 bundled the Worker successfully in dry-run mode. These checks are not substitutes for live-provider or emulator authorization tests.

The owner-run Auth/Firestore emulator suite passed all 18 tests, and current v2 rules/index deployment was confirmed on November 6, 2026. The local receipt at 2026-11-06T12:11:15.996797+00:00 matches the current rule hash; anonymous account/marker reads were denied. Dedicated server credentials and the legacy consent/ranking migration were also owner-confirmed. The owner subsequently registered the workers.dev namespace, deployed Worker version fdf02b4f-5690-48d4-8a0b-78dc7a96d9a9 to https://watchloom-community.watchloom-canturhan.workers.dev and bound all three secrets. Owner-run diagnostics passed Google OAuth, Auth lookup, both indexes and synthetic OpenAI classification. Public Worker DNS and TLS also passed, but its HTTP request failed before a response; native HTTPS/fetch comparison is pending. These local dependency checks do not establish deployed Worker readiness. Automatic-mode activation, live Worker provider health and build 9 upload remain unverified. The managed session cannot independently use Google APIs or bind emulator ports; owner-run results and device evidence remain distinct.

Device QA: Apple/Google/email sign-in, existing-user new consent, allowed/unsafe Turkish/English text and names, outage/retry, two-user up/down/switch/withdraw/order, no self-voting, reporting/blocking/spoilers, and account deletion with outstanding votes. Verify App Store Connect processing after a successful upload.

## Primary references

- [Apple App Review Guidelines 1.2 and 5.1.2](https://developer.apple.com/app-store/review/guidelines/)
- [Firebase plans](https://firebase.google.com/docs/projects/billing/firebase-pricing-plans)
- [Workers Free limits](https://developers.cloudflare.com/workers/platform/limits/)
- [OpenAI Moderation API](https://developers.openai.com/api/docs/guides/moderation)
- [OpenAI data controls](https://developers.openai.com/api/docs/guides/your-data)

This record describes implementation and evidence; it does not guarantee zero bugs or certify every country's legal requirements.

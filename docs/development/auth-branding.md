# Watchloom authentication branding

## Resume here — ownership verified, waiting for Google propagation

- The user confirmed Search Console ownership verification succeeded for the
  URL-prefix property `https://canturhan.github.io/watchloom/`.
- The exact HTML verification tag is in `docs/index.html`, published to `main`
  in commit `485460864a58484e66f3910887dd99a57d14bb58`. Its presence on the live
  homepage was verified. Keep the tag permanently.
- Google asked to wait 24 hours after ownership verification before retrying.
  The exact verification time was not recorded; confirm elapsed time with the
  user rather than assuming the waiting period has passed.
- Next: Google Auth Platform → Branding → Verify Branding. If approved,
  Publish branding, then check a new Google sign-in notification for the
  Watchloom name. Search Console URL-prefix success does not yet prove that
  OAuth brand verification will accept the hosted domain.
- Firebase verification/reset/email-change Sender name changes to Watchloom
  remain unconfirmed. Read the current settings before making further changes.
- No new app build is needed. Preserve existing OAuth clients, redirect URIs,
  scopes, provider settings, users and app data. No follow-up reminder was set;
  the user plans to return after 24 hours.

Checked on 2026-11-16. This document records proposed console values; it does
not mean that Google branding has been saved, verified or published.

## Google Auth Platform → Branding

Project: `watchloom-canturhan`, number `157774090938`.

| Field | Value |
| --- | --- |
| App name | `Watchloom` |
| User support email | `can.turhan.web@gmail.com`, if selectable by the project owner |
| App logo | `assets/branding/watchloom_oauth_120.png` |
| Application home page | `https://canturhan.github.io/watchloom/` |
| Application privacy policy link | `https://canturhan.github.io/watchloom/privacy.html` |
| Application terms of service link | `https://canturhan.github.io/watchloom/terms.html` |
| Authorized domain for the website | `canturhan.github.io` |
| Developer contact email | `can.turhan.web@gmail.com` |

Enter domain names without a scheme, path or trailing slash. Do not enter
`github.io`: it is a shared hosting suffix. Preserve existing authorized domains
used by OAuth clients, including the existing Firebase callback host. Do not
replace any OAuth client IDs, redirect URIs, scopes, app identifiers or secrets.

The logo is an unchanged copy of the existing 120×120 iOS app icon, PNG,
18,033 bytes. All three website URLs returned HTTP 200. The privacy and terms
responses differ from the local files, so availability does not establish that
the newest repository versions have been published.

The current public website uses GitHub Pages. This is not proof of domain
ownership for Google brand verification. Google's current domain verification
guidance requires a DNS-level Domain property; a URL-prefix Search Console
verification must not be promised as sufficient. The owner cannot manage DNS
for `github.io`. If Google rejects the hosted subdomain, resolve the finding
with Google or use an owned, DNS-verified domain before claiming completion.
Do not change the app audience to Internal or Testing merely to bypass review.

Save the branding draft. If Google requests verification, complete it, then
publish the approved branding. The name/logo may not appear publicly until
verification and publication finish. Existing received emails will not change.
The Google branding console is not accessible through the connected tools in
this session; its current draft/published name and review status are unverified.

## Firebase Authentication → Templates

Initial read-only checks confirmed:

- Firebase project display name is already `Watchloom`.
- Email/password, Google and Apple providers are enabled.
- Verification, password reset and email-change templates use `%APP_NAME%`.
- Sender display names use the defaults.
- Action URL is
  `https://watchloom-canturhan.firebaseapp.com/__/auth/action`.
- Firebase Auth authorized domains are `localhost`,
  `watchloom-canturhan.firebaseapp.com`, `watchloom-canturhan.web.app`.
  This list is separate from Google OAuth Branding authorized domains.

For these three email templates, set **Sender name** to `Watchloom`. Keep
`%APP_NAME%` in the existing localized template text: Firebase documents that
an available OAuth brand name supplies that value. Correcting the Google brand
is needed as well as the sender header. Preserve `%LINK%`, action URL, sending
address, SMTP configuration and all account security settings. A custom sending
domain is not required merely to set the sender display name.

No Firebase settings, users, comments, votes, backups or application code were
modified during these checks. No test emails were sent. After saving, use the
normal app flows with an owner-controlled account to check a new Google consent
notification, verification email and password-reset email; never post action
links or credentials in logs or public issues. No new iOS build is required for
these server-side branding settings.

### Applied follow-up — 2026-11-18

The owner explicitly authorized the email branding update. Firebase Console
General settings showed both project name and **Public-facing name** already
set to `Watchloom`. The three email sender display names were still defaults.

`node scripts/configure_auth_email_branding.cjs --apply` updated only
`notification.sendEmail.{verifyEmailTemplate,resetPasswordTemplate,changeEmailTemplate}.senderDisplayName`
to `Watchloom`, using an explicit field mask. A subsequent GET verified all
three sender names and compared the rest of Auth configuration in memory.
Templates retain `%APP_NAME%` and `%LINK%`; message bodies, localized subjects,
action URL, SMTP, sender address, authorized domains and sign-in settings were
preserved. No message was sent and no account/user data was modified.

Run `node scripts/configure_auth_email_branding.cjs --check` for a read-only
check. The command is restricted to `watchloom-canturhan` and prints no token,
SMTP config, recipient or action link. `--apply` is idempotent.

A newly delivered verification/reset email still needs checking from an
owner-controlled device/account to confirm the resolved app name and inbox
appearance. This is separate from Google's own OAuth security notification,
which uses the published OAuth brand and its verification status.

### Owner-requested delivery test — 2026-11-18

The owner explicitly requested a test email to their designated address.
A `VERIFY_EMAIL` request using administrative authorization without a user
ID token was rejected with `INVALID_ID_TOKEN`; no verification email was
confirmed sent. No custom-token sign-in or account verification reset was used.

One `PASSWORD_RESET` email request was then accepted by Firebase, using the
same `%APP_NAME%` branding and the updated `Watchloom` sender name, with Turkish
locale requested. A reset email does not change the password unless its reset
flow is completed. The account, providers, verification state and library data
were not modified. No response/action link or credential was logged or saved.
Inbox arrival and the rendered brand text await the owner's confirmation;
this is not a successful verification-template delivery test.

The owner subsequently confirmed that the received test email displays
`Watchloom`. This verifies the branding in the delivered reset email; it does
not change the separate verification-template/session test requirement.

## Official references

- https://support.google.com/cloud/answer/15549049?hl=en
- https://support.google.com/cloud/answer/13804266?hl=en
- https://firebase.google.com/docs/auth/faq-and-troubleshooting
- https://support.google.com/firebase/answer/7000714?hl=en

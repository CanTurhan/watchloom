# Watchloom 1.2.3 (14)

## Changes

- Authors can edit their own comments and replies. Text and spoiler edits return the same document to pending moderation; original author, creation date, content identity, vote totals and viewing snapshot are preserved. Stale edit revisions cannot overwrite a newer edit. Unchanged drafts do not submit a new moderation request.
- Newly submitted comments display a self-reported viewing snapshot: season/episode for series, watched/not-yet-watched for movies. For example, Friends can show `8. sezon · 5. bölüm` / `Season 8 · Episode 5`. Unstarted titles show `Henüz izlenmedi` / `Not watched yet`. Existing comments without a snapshot say the status was not shared; no historical viewing data is invented.
- Movie discussions use IMDb-based movie keys in the client, Firestore rules and moderation service. Existing TVMaze series keys and old comment documents remain compatible. The composer explains the public snapshot before sending; private library notes and full history remain private. The snapshot is not sent to OpenAI.
- Movie/series summary placeholders, search hints, empty/search-failure states, favorites and removal messages reflect the selected media type. Movie metadata panels no longer request TVMaze series metadata for a movie ID.
- The navigation tab is now `Özet` / `Recap`. Period controls show Today/Yesterday/Tomorrow, the selected date, This month/month name, or the selected year. Reset tooltips explain the button action. Arrows and horizontal swipes select the same period; month/year changes preserve and safely clamp the day, including leap years. Existing stats and current-month story sharing remain available.
- All new copy is supplied in both supported app languages, Turkish and English. Published legal notices are synchronized with the in-app disclosure.

## Verification

- Flutter analyzer: passed.
- Full Flutter suite: 197 tests passed, including comment edit prefilling, preserved votes/viewing context, account changes, movie artwork, localized labels and actual recap arrow/swipe interactions.
- Python suite: 33 tests passed.
- Node/server suite: 64 tests passed, including movie contexts and stale moderation rejection after an edit revision change.
- Auth/Firestore emulator suite: 19 tests passed, including owner-only edits, immutable vote/context fields, pending visibility, revision checks and invalid movie/series combinations.
- Actual Worker runtime checks passed. Licenses and in-app/hosted community notice checks passed.

## Distribution

Source branch remains `version_1.2.0_11`; App Store metadata is `1.2.3+14`. Firestore and Worker source changes must be deployed and live readiness verified before TestFlight upload. Local test/build success is not proof of deployment, App Store Connect acceptance or production publication. No production App Store submission is requested by this release task.

Deployment evidence: Worker version `d3acf1db-ec40-46d4-b8ce-ed1e0d62820a` was successfully published to the existing `watchloom-community` service. The complete emulator suite passed again in the Firestore deployment flow; Firestore rules/index publication completed and the deployment receipt/security checks passed. Existing server secrets and Spark billing configuration were preserved. A native iOS archive and TestFlight upload are tracked separately below.

Final distribution evidence: the signed 1.2.3 (14) archive and IPA were created; metadata and archive signature verification passed. Refreshing the verified migration receipt updated **0** comment/report documents and preserved all existing votes. Live Worker/provider/IAM/index/health checks passed. Xcode uploaded the archive using the configured App Store Connect account and returned `Upload succeeded` / `EXPORT SUCCEEDED`; Apple reported `Uploaded package is processing`. The build is uploaded for TestFlight, with Apple's remaining processing and device QA not yet verified. No production App Review submission or public release was performed.

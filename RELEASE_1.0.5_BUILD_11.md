# Watchloom 1.0.5 (11)

Branch: `version_1.2.0_11`, based on `version_1.2.0_10` / `95e51fd`.

## Changes

- Library and watchlist sharing through the system share sheet, including WhatsApp when installed. Titles, status, progress and source links are included; private notes are excluded.
- Movie search and details through Cinemeta's metadata API, with a separate IMDb ID namespace that preserves existing TVMaze series IDs. Series searches continue to use TVMaze.
- Movie library filtering alongside existing watching, watchlist, completed and favorite filters. Marking a movie watched completes it and adds its actual runtime to viewing activity without increasing episode/series counts.
- Movie trailers and IMDb-matched series trailers open in YouTube after confirmation for restricted or unknown ratings. Missing ratings are explicitly unknown; missing trailers are omitted. Trailers do not autoplay.
- Watch confirmation messages retain Undo and disappear after two seconds on both Home and Library. Repeated messages do not accumulate.
- Home's watchlist includes titles currently being watched.
- Library progress edits save new episode events and progress in one SQLite transaction. Repeating a save does not duplicate events. Rewinding progress removes later events, and failed/future-episode edits roll back. Existing event dates are preserved for unchanged progress.
- Daily, monthly and yearly activity selection and date navigation; separate movie counts and total viewing minutes, including movies in active-day/streak calculations.
- SQLite v5 → v6 migration preserves existing series, notes and favorites. Movie backups use schema 2 so older clients cannot silently restore movies as series; current clients still read schema 1.
- Privacy notices describe the added metadata provider, external trailer opening and list sharing.

## Verification

- `flutter analyze --no-pub lib test tool/check_media_catalog.dart`: passed.
- Full Flutter suite: 180 tests passed.
- Python suite: 33 tests passed, including actual SQLite upgrade preservation.
- Existing Node/Worker runtime checks in `scripts/release_ios.sh --check`: passed.
- Runtime/native licenses, hosted community notices and installed Firebase iOS security checks: passed.
- `dart run tool/check_media_catalog.dart`: live movie search, Inception's 148-minute runtime, movie watch metadata, and both movie and Breaking Bad trailers verified.
- Widget regression checks cover automatic snackbar dismissal, movie/favorite filters, age warnings/cancellation and daily/monthly/yearly controls on a 320px screen at 180% text scale in Turkish and English.
- Signed archive/IPA metadata validation: version `1.0.5`, build `11`, iOS `15.0`, bundle `com.canturhan.watchloom`.

## Distribution status and limits

The live moderation release gate currently fails with `EPROTO` against `https://watchloom-community.watchloom-canturhan.workers.dev`. Native Node HTTPS, TLS, fetch and system curl all failed during diagnostics. The release gate was preserved; production upload has not been performed. No moderation deployment, credentials or backend access rules were changed.

The verified IPA is generated locally at `build/ios/ipa/Watchloom.ipa`; build artifacts are not committed. Once the live gate succeeds, `bash scripts/release_ios.sh --upload-existing` verifies and uploads the current archive using Xcode's configured distribution account.

Existing progress that never had watch events cannot reveal historical watch dates; this release does not invent those dates. Future edits create dated events. Unknown runtimes remain explicitly excluded from duration totals. Trailer availability and rating coverage depend on the provider. Sharing and trailer launching still require real-device validation with the intended recipient apps. App Store Connect processing, review and production availability have not been verified.

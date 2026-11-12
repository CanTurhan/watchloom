# Watchloom 1.2.2 (13)

Movie artwork correction only. Search results, saved library movies, Home cards and movie detail headers now share the same poster rendering. Series keep their existing rendering.

Movie posters are resolved by the saved IMDb identity, including saved movies with no poster URL. Catalog-provided HTTPS artwork is retained, known Metahub thumbnails are normalized to medium size, and the existing provider's alternative image host is tried if loading fails. No title searches, data migrations, library edits or tracking changes are needed.

Both provider image hosts returned TLS errors on this network during verification. Successful movie poster delivery is therefore not claimed here. While loading, or if no image can be loaded, the bundled Watchloom logo is centered using `BoxFit.contain`; it is not cropped or stretched. Real posters use the existing card dimensions with `BoxFit.cover`. Detail headers preserve the readability gradient.

Tests cover exact movie identity, old saved movies without URLs, missing/invalid sources, ordered image fallbacks, bundled logo availability, and logo fit in 54×72, 96×160 and 390×365 areas. Existing movie filters and other UI regressions are exercised by the full Flutter suite.

Source branch: `version_1.2.0_11`. Current release metadata: `1.2.2+13`. Build artifacts are generated at `build/ios/archive/Runner.xcarchive` and `build/ios/ipa/Watchloom.ipa` and verified with `python3 scripts/verify_ios_artifacts.py`.

TestFlight upload and App Store publication must be reported separately from successful local build creation. The existing live moderation TLS gate was not removed or weakened.

Verification: all 186 Flutter tests passed; analyzer, runtime/native licenses, hosted notices and installed Firebase iOS security checks passed. Xcode created the 1.2.2 (13) archive and archive metadata verification passed. The first IPA export failed because the Xcode account could not log in and an iOS Distribution certificate was unavailable; the keychain check found only an Apple Development identity. A distribution export retry uses `-allowProvisioningUpdates`. Do not treat a successful Flutter archive exit as proof that an IPA exists or was uploaded. The live moderation gate also still returned `EPROTO`.

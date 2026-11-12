# Watchloom 1.2.1 (12)

This release supersedes the rejected 1.0.5 (11) distribution artifact. App Store Connect confirmed that the previously approved version is 1.2.0, so the new marketing version is 1.2.1 and the build number is 12. The Git branch remains `version_1.2.0_11` as requested; Git branch names do not determine the App Store version.

The application features and fixes are unchanged from `RELEASE_1.0.5_BUILD_11.md`. Only release metadata and the HTTP User-Agent version change. Earlier archives are retained separately to prevent accidental selection as the current build.

The current archive and IPA are produced at `build/ios/archive/Runner.xcarchive` and `build/ios/ipa/Watchloom.ipa`. Verify both with `python3 scripts/verify_ios_artifacts.py`; select **1.2.1 (12)** in Xcode Organizer. App Store Connect must use a new **1.2.1** version, rather than the closed 1.2.0 version or the rejected 1.0.5 version.

The existing live moderation TLS verification failure remains separate from Apple's version-number rejection; updating the version does not resolve that connection issue. Upload/processing success must be confirmed separately.

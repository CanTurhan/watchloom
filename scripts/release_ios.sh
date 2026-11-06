#!/usr/bin/env bash
set -euo pipefail

release_action="${1:---check}"
if [[ $# -gt 1 ]]; then
  printf 'Usage: bash scripts/release_ios.sh [--check|--build-testflight|--archive-xcode|--build|--upload-testflight|--upload-existing]\n' >&2
  exit 2
fi
case "$release_action" in
  --check|--build-testflight|--archive-xcode|--build|--upload-testflight|--upload-existing) ;;
  *) printf 'Usage: bash scripts/release_ios.sh [--check|--build-testflight|--archive-xcode|--build|--upload-testflight|--upload-existing]\n' >&2; exit 2 ;;
esac

project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_dir"
flutter_bin="${WATCHLOOM_FLUTTER_BIN:-flutter}"

upload_archive() {
  xcodebuild -exportArchive \
    -archivePath "$project_dir/build/ios/archive/Runner.xcarchive" \
    -exportPath "$project_dir/build/ios/upload" \
    -exportOptionsPlist "$project_dir/ios/ExportOptions-TestFlight.plist" \
    -allowProvisioningUpdates
}

if [[ "$release_action" == '--upload-existing' ]]; then
  python3 scripts/check_firebase_release.py
  python3 scripts/check_firestore_release.py
  node scripts/configure_community_automation.cjs verify
  python3 scripts/check_ios_security.py
  python3 scripts/verify_ios_artifacts.py --archive-only
  upload_archive
  printf '\nUpload completed. App Store Connect will process the build for TestFlight.\n'
  exit 0
fi

"$flutter_bin" pub get --offline
python3 scripts/sync_web_licenses.py --check
python3 scripts/sync_community_notices.py --check
"$flutter_bin" analyze --no-pub lib test
python3 -m unittest discover -s scripts -p 'test_*.py'
node --test scripts/test_firebase_spark.cjs scripts/test_firebase_apple.cjs scripts/community_moderation_test.cjs \
  scripts/community_automation_test.cjs scripts/community_diagnostics_test.cjs server/community-worker/test/*.test.mjs

if [[ "${WATCHLOOM_TEST_RUNNER:-}" == 'lightweight' ]]; then
  # Flutter's lightweight runner does not need a localhost debugging socket.
  python3 - <<'PY'
import json
from pathlib import Path
path = Path('.dart_tool/package_config.json')
config = json.loads(path.read_text())
for package in config['packages']:
    if package['name'] == 'watchloom':
        package['rootUri'] = Path.cwd().as_uri() + '/'
path.write_text(json.dumps(config, indent=2) + '\n')
PY
  "$flutter_bin" test --experimental-faster-testing --no-pub
else
  "$flutter_bin" test --no-pub
fi

if [[ "$release_action" == '--check' ]]; then
  python3 scripts/check_firebase_release.py
  python3 scripts/check_firestore_release.py
  node scripts/configure_community_automation.cjs verify
  python3 scripts/check_ios_security.py
  printf '\nChecks passed. No archive or upload was requested.\n'
  exit 0
fi

python3 scripts/check_firebase_release.py
python3 scripts/check_firestore_release.py
node scripts/configure_community_automation.cjs verify
python3 scripts/check_ios_security.py

# Preserve the previous export outside Flutter's output directory. A failed
# export must never leave an older IPA available to the verification step,
# even when both artifacts happen to carry the same build number.
if [[ -d build/ios/ipa ]]; then
  previous_export_dir="$(mktemp -d "$project_dir/build/ios/previous-ipa.XXXXXX")"
  mv -- build/ios/ipa "$previous_export_dir/ipa"
  printf '\nPrevious IPA preserved in: %s/ipa\n' "$previous_export_dir"
fi

archive_path="$project_dir/build/ios/archive/Runner.xcarchive"
if [[ -d "$archive_path" ]]; then
  previous_archive_dir="$(mktemp -d "$project_dir/build/ios/previous-archive.XXXXXX")"
  mv -- "$archive_path" "$previous_archive_dir/Runner.xcarchive"
  printf '\nPrevious archive preserved in: %s/Runner.xcarchive\n' "$previous_archive_dir"
fi

if [[ "$release_action" == '--archive-xcode' || "$release_action" == '--upload-testflight' ]]; then
  "$flutter_bin" build ios --config-only --release --no-pub --no-codesign \
    --dart-define=WATCHLOOM_TEST_ADS=true
  (cd ios && pod install)
  python3 scripts/sync_ios_licenses.py
  python3 scripts/sync_web_licenses.py --check
  mkdir -p build/release-audit
  result_directory="$(mktemp -d "$project_dir/build/release-audit/native-build.XXXXXX")"
  xcodebuild -workspace "$project_dir/ios/Runner.xcworkspace" -scheme Runner \
    -configuration Release -destination 'generic/platform=iOS' \
    -derivedDataPath "$project_dir/build/ios/DerivedData" \
    -archivePath "$archive_path" -resultBundlePath "$result_directory/Archive.xcresult" \
    -allowProvisioningUpdates archive
  python3 scripts/verify_ios_artifacts.py --archive-only
  if [[ "$release_action" == '--upload-testflight' ]]; then
    upload_archive
    printf '\nQA build uploaded. App Store Connect will process it for TestFlight.\n'
    exit 0
  fi
  xcodebuild -exportArchive -archivePath "$archive_path" \
    -exportPath "$project_dir/build/ios/ipa" \
    -exportOptionsPlist "$project_dir/ios/ExportOptions-AppStore.plist" \
    -allowProvisioningUpdates
  printf '\nXcode QA build: Yandex test ads are enabled.\n'
elif [[ "$release_action" == '--build-testflight' ]]; then
  "$flutter_bin" build ipa --release --no-pub --export-method app-store \
    --dart-define=WATCHLOOM_TEST_ADS=true
  printf '\nQA build: Yandex test ads are enabled.\n'
else
  "$flutter_bin" build ipa --release --no-pub --export-method app-store \
    --dart-define=WATCHLOOM_TEST_ADS=false
fi

# Flutter may report a successful archive even when exporting the IPA failed.
# Reject a missing or stale IPA before it can be selected for upload.
python3 scripts/verify_ios_artifacts.py
for archived_app in "$archive_path/Products/Applications/"*.app; do
  python3 scripts/privacy_manifest_inventory.py "$archived_app" \
    --output build/release-audit/archive-privacy.json
done
printf '\nUse Xcode Organizer or Transporter to upload the verified build.\n'

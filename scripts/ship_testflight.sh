#!/usr/bin/env bash
# Run in the owner's normal Mac Terminal: emulators and Apple distribution need
# localhost/network/Keychain access that is unavailable in the managed session.
set -eEuo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
if [[ $# -gt 1 || ( $# -eq 1 && "${1:-}" != '--resume' ) ]]; then
  printf 'Usage: bash scripts/ship_testflight.sh [--resume]\n' >&2
  exit 2
fi
watchloom_release_phase='Automatic community, emulator tests and verified Spark deployment'
trap 'printf "\nStopped during: %s. TestFlight completion was not verified.\n" "$watchloom_release_phase" >&2' ERR
if [[ "${1:-}" == '--resume' ]]; then
  # Current rule/migration receipts and real Worker/provider health are still
  # mandatory. Resume only after the stable Worker and secrets were deployed.
  watchloom_release_phase='Live verification and activation of the deployed automatic community'
  node scripts/configure_community_automation.cjs activate \
    https://watchloom-community.watchloom-canturhan.workers.dev \
    --accept-automated-moderation-responsibility
else
  bash scripts/setup_community_automation.sh --deploy
fi
watchloom_release_phase='Source checks, signed QA archive and TestFlight upload'
bash scripts/release_ios.sh --upload-testflight
printf '\nUpload command completed. Check App Store Connect processing and test the new build on your device.\n'

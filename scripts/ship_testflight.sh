#!/usr/bin/env bash
# Run in the owner's normal Mac Terminal: emulators and Apple distribution need
# localhost/network/Keychain access that is unavailable in the managed session.
set -eEuo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
watchloom_release_phase='Automatic community, emulator tests and verified Spark deployment'
trap 'printf "\nStopped during: %s. TestFlight completion was not verified.\n" "$watchloom_release_phase" >&2' ERR
bash scripts/setup_community_automation.sh --deploy
watchloom_release_phase='Source checks, signed QA archive and TestFlight upload'
bash scripts/release_ios.sh --upload-testflight
printf '\nUpload command completed. Check App Store Connect processing and test the new build on your device.\n'

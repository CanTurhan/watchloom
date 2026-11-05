#!/usr/bin/env bash
# Resolve only the Firebase native dependency family onto the security backport.
set -euo pipefail
watchloom_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$watchloom_root/ios"
pod update Firebase FirebaseCore FirebaseCoreInternal FirebaseCoreExtension \
  FirebaseAuth FirebaseAuthInterop FirebaseAppCheckInterop FirebaseFirestore \
  FirebaseFirestoreInternal FirebaseSharedSwift --repo-update
cd "$watchloom_root"
python3 scripts/check_ios_security.py
python3 scripts/sync_ios_licenses.py
echo 'Native dependencies updated. Rebuild and rerun the account/device tests before TestFlight.'

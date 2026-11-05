#!/usr/bin/env bash
# Run from a normal macOS Terminal if the agent session cannot reach Google.
# Creates exactly one project. Does not enable billing, Analytics or paid APIs.
set -euo pipefail
WATCHLOOM_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WATCHLOOM_PROJECT_ID="${1:-}"
if [[ ! "$WATCHLOOM_PROJECT_ID" =~ ^[a-z][a-z0-9-]{4,28}[a-z0-9]$ ]]; then
  echo 'Usage: bash scripts/setup_firebase_project.sh <unique-project-id>' >&2
  exit 1
fi
cd "$WATCHLOOM_ROOT"
firebase projects:create "$WATCHLOOM_PROJECT_ID" --display-name Watchloom
firebase apps:create IOS Watchloom --bundle-id com.canturhan.watchloom --project "$WATCHLOOM_PROJECT_ID"
firebase apps:list IOS --project "$WATCHLOOM_PROJECT_ID" --json > .firebase-ios-apps.tmp.json
WATCHLOOM_APP_ID="$(python3 - <<'PY'
import json
from pathlib import Path
data=json.loads(Path('.firebase-ios-apps.tmp.json').read_text())
result=data.get('result',[])
apps=result if isinstance(result,list) else result.get('apps',[])
matches=[app for app in apps if app.get('bundleId') == 'com.canturhan.watchloom']
if len(matches)!=1:
    raise SystemExit('Expected exactly one Watchloom iOS registration. Inspect Firebase Console before continuing.')
print(matches[0]['appId'])
PY
)"
rm .firebase-ios-apps.tmp.json
firebase apps:sdkconfig IOS "$WATCHLOOM_APP_ID" --project "$WATCHLOOM_PROJECT_ID" --out /private/tmp/watchloom-GoogleService-Info.plist
echo "Firebase project created: $WATCHLOOM_PROJECT_ID"
echo 'Enable Google in Firebase Console → Authentication → Sign-in method first.'
echo "Then download the updated iOS GoogleService-Info.plist and run:"
echo 'python3 scripts/configure_firebase_ios.py /path/to/GoogleService-Info.plist'
echo 'Do not enable billing automatically. Backend deployment needs a separate billing decision.'

#!/usr/bin/env bash
# Spark only: test locally, then deploy Firestore rules/indexes. No billing,
# Functions, Scheduler, Cloud Run, Storage bucket or service-account creation.
set -euo pipefail
watchloom_action="${1:---check}"
case "$watchloom_action" in
  --check|--deploy) ;;
  *) echo 'Usage: bash scripts/deploy_firebase.sh [--check|--deploy]' >&2; exit 2 ;;
esac
watchloom_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$watchloom_root"
watchloom_phase='Java runtime detection'
watchloom_databases=''
watchloom_cleanup() {
  local watchloom_exit=$?
  if [[ -n "$watchloom_databases" ]]; then rm -f "$watchloom_databases"; fi
  if [[ "$watchloom_exit" -ne 0 ]]; then
    printf 'Firebase setup stopped during: %s (exit %s). Completion was not verified. Check the error above before retrying.\n' "$watchloom_phase" "$watchloom_exit" >&2
  fi
}
trap watchloom_cleanup EXIT
# macOS may have a working Android Studio/Homebrew JDK that its /usr/bin/java
# wrapper cannot discover. Select a compatible runtime only for this command.
watchloom_java_home="$(python3 - <<'PY'
import os, re, subprocess
from pathlib import Path
candidates=[]
if os.environ.get('JAVA_HOME'): candidates.append(Path(os.environ['JAVA_HOME']))
candidates.extend([Path('/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home'),
    Path('/usr/local/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home'),
    Path('/Applications/Android Studio.app/Contents/jbr/Contents/Home')])
for base in [Path.home()/'Library/Java/JavaVirtualMachines',Path('/Library/Java/JavaVirtualMachines')]:
    if base.exists(): candidates.extend(p/'Contents/Home' for p in base.iterdir())
for candidate in candidates:
    binary=candidate/'bin/java'
    if not binary.is_file(): continue
    try:
        check=subprocess.run([str(binary),'-version'],capture_output=True,text=True,timeout=10)
        version=re.search(r'(?:openjdk|java) version "(\d+)',check.stderr+check.stdout)
        if check.returncode==0 and version and int(version.group(1))>=21:
            print(candidate); break
    except (OSError,subprocess.TimeoutExpired): continue
else:
    raise SystemExit('Java 21+ is required by the Firestore test emulator. Install with: brew install openjdk@21, then rerun this command.')
PY
)"
export JAVA_HOME="$watchloom_java_home"
export PATH="$JAVA_HOME/bin:$PATH"
printf 'Using Java runtime: %s\n' "$watchloom_java_home"
watchloom_phase='iOS client configuration'
python3 scripts/check_firebase_release.py
watchloom_project="$(python3 - <<'PY'
from pathlib import Path
import json, plistlib
config=plistlib.loads(Path('ios/Runner/GoogleService-Info.plist').read_bytes())
deploy=json.loads(Path('firebase.json').read_text())
if set(deploy)-{'firestore','emulators'}:
    raise SystemExit('Spark deployment must contain only Firestore and local emulators.')
print(config['PROJECT_ID'])
PY
)"
# The local test uses a demo project and loopback emulators, never real users.
watchloom_phase='local test dependencies'
npm ci --prefix firebase/tests --no-audit --no-fund
watchloom_phase='local security-rule tests'
firebase emulators:exec --project demo-watchloom --only auth,firestore \
  'node --test firebase/tests/rules.test.cjs'
if [[ "$watchloom_action" == '--check' ]]; then
  echo 'Local Spark security tests passed. No cloud changes requested.'
  exit 0
fi
watchloom_phase='Spark billing verification and Firestore API activation'
node scripts/check_firebase_spark.cjs "$watchloom_project" --enable-firestore
watchloom_databases="$(mktemp /private/tmp/watchloom-databases.XXXXXX)"
watchloom_phase='Firestore database lookup'
if firebase firestore:databases:list --project "$watchloom_project" --json > "$watchloom_databases"; then
  :
else
  python3 - "$watchloom_databases" <<'PY'
import json, sys
try: print(json.load(open(sys.argv[1])).get('error','Firestore database lookup failed.'),file=sys.stderr)
except ValueError: print('Firestore database lookup failed. Inspect firebase-debug.log locally.',file=sys.stderr)
PY
  exit 1
fi
watchloom_database_state="$(python3 - "$watchloom_databases" <<'PY'
import json, sys
data=json.load(open(sys.argv[1])); result=data.get('result')
databases=result if isinstance(result,list) else result.get('databases',[]) if isinstance(result,dict) else None
if databases is None: raise SystemExit('Unrecognized database response. No database created.')
matches=[db for db in databases if db['name'].endswith('/databases/(default)')]
if not matches: print('create')
else:
    db=matches[0]
    if db.get('locationId')!='europe-west1' or db.get('type')!='FIRESTORE_NATIVE':
        raise SystemExit('Existing database has a different region/type. Inspect it before continuing; it was not changed.')
    print('exists')
PY
)"
if [[ "$watchloom_database_state" == 'create' ]]; then
  watchloom_phase='default free Firestore database creation'
  firebase firestore:databases:create '(default)' --location europe-west1 --edition standard \
    --delete-protection ENABLED --project "$watchloom_project"
fi
watchloom_phase='Firestore rule and index publication'
firebase deploy --only firestore:rules,firestore:indexes --project "$watchloom_project"
watchloom_phase='Firestore deployment verification'
python3 - "$watchloom_project" <<'PY'
from pathlib import Path
from datetime import datetime, timezone
import hashlib, json, sys
target=Path('build/release-audit/firestore-deployment.json'); target.parent.mkdir(parents=True,exist_ok=True)
target.write_text(json.dumps({'projectId':sys.argv[1], 'rulesSha256':hashlib.sha256(Path('firebase/firestore.rules').read_bytes()).hexdigest(),
    'emulatorTestsPassed':True, 'deployedAt':datetime.now(timezone.utc).isoformat()}, indent=2)+'\n')
PY
python3 scripts/check_firestore_release.py
echo 'Spark Firestore deployment verified. Continue with Apple sign-in and real-device account/deletion/reinstall tests.'

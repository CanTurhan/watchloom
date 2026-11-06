#!/usr/bin/env bash
# Free-tier deployment. No Firebase Functions, billing upgrade or paid Worker feature.
set -euo pipefail
watchloom_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$watchloom_root"
if [[ "${1:-}" != '--deploy' || $# -ne 1 ]]; then
  printf 'Usage: bash scripts/setup_community_automation.sh --deploy\n' >&2
  exit 2
fi
watchloom_phase='local server/security checks'
trap 'watchloom_exit=$?; if [[ "$watchloom_exit" -ne 0 ]]; then printf "Stopped during: %s. Automatic moderation completion was not verified.\n" "$watchloom_phase" >&2; fi' EXIT
export WRANGLER_SEND_METRICS=false
watchloom_wrangler=(npx --yes wrangler@4.158.0)
watchloom_phase='Cloudflare CLI authentication'
if ! "${watchloom_wrangler[@]}" whoami --json > /dev/null; then
  printf 'Cloudflare CLI verification failed. Inspect the Wrangler error or run npx --yes wrangler@4.158.0 whoami --json in your normal Terminal. A network error does not require another login. No Firebase deployment was attempted.\n' >&2
  exit 1
fi
watchloom_phase='local server/security checks'
node --test server/community-worker/test/*.test.mjs scripts/community_automation_test.cjs
python3 -m unittest discover -s scripts -p 'test_*.py'
watchloom_phase='emulator-tested Spark rules and indexes'
bash scripts/deploy_firebase.sh --deploy
watchloom_phase='private Google service identity'
node scripts/configure_community_automation.cjs prepare
watchloom_phase='legacy scores and consent migration'
node scripts/configure_community_automation.cjs migrate
watchloom_phase='Cloudflare Free Worker deployment'
mkdir -p build/release-audit
watchloom_deploy_result="$(mktemp "$watchloom_root/build/release-audit/community-worker-deploy.XXXXXX")"
# Keep stdin/stdout attached to the Terminal for first-account subdomain prompts.
# Wrangler writes a separate machine-readable receipt; no console scraping.
if ! WRANGLER_OUTPUT_FILE_PATH="$watchloom_deploy_result" \
  "${watchloom_wrangler[@]}" deploy --config server/community-worker/wrangler.jsonc; then
  exit 1
fi
watchloom_endpoint="$(python3 scripts/read_worker_deployment.py "$watchloom_deploy_result")"
watchloom_phase='encrypted server secret bindings'
"${watchloom_wrangler[@]}" secret bulk "$HOME/.config/watchloom/community/worker-secrets.json" \
  --config server/community-worker/wrangler.jsonc
watchloom_phase='real provider/IAM/index checks and automatic-mode activation'
node scripts/configure_community_automation.cjs activate "$watchloom_endpoint" --accept-automated-moderation-responsibility
printf '\nAutomatic community moderation deployed. Test comments, votes, reports and account deletion in build 9 before App Review.\n'

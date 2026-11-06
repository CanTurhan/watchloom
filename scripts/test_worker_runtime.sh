#!/usr/bin/env bash
# Synthetic integration checks in Cloudflare's actual runtime, with no sockets,
# live credentials or internet access available to the test Worker.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
export WRANGLER_SEND_METRICS=false
npx --yes --package=wrangler@4.158.0 -- workerd test server/community-worker/test/runtime/config.capnp

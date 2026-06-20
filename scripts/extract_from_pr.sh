#!/usr/bin/env bash
# Pull the forecast_solar integration from the PR branch into this repo.
# Usage:  scripts/extract_from_pr.sh [PR_BRANCH]
# Default branch: add-forecast-solar-service on purcell-lab/core.
set -euo pipefail

PR_REMOTE_URL="${PR_REMOTE_URL:-https://github.com/purcell-lab/core.git}"
PR_BRANCH="${1:-add-forecast-solar-service}"

REPO_ROOT="$(git rev-parse --show-toplevel)"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

echo "Cloning $PR_REMOTE_URL @ $PR_BRANCH (sparse) into $TMPDIR ..."
git clone --depth 1 --branch "$PR_BRANCH" --no-checkout "$PR_REMOTE_URL" "$TMPDIR/core" >/dev/null
cd "$TMPDIR/core"
git sparse-checkout init --cone >/dev/null
git sparse-checkout set homeassistant/components/forecast_solar >/dev/null
git checkout "$PR_BRANCH" >/dev/null
PR_SHA=$(git rev-parse --short HEAD)
cd - >/dev/null

DEST="$REPO_ROOT/custom_components/forecast_solar"
echo "Syncing $TMPDIR/core/homeassistant/components/forecast_solar -> $DEST"

# Preserve our manifest.json (we patch name/version/documentation). Everything else is verbatim.
cp "$DEST/manifest.json" "$TMPDIR/manifest.local.json"
rsync -a --delete \
  --exclude '__pycache__' \
  "$TMPDIR/core/homeassistant/components/forecast_solar/" "$DEST/"

# Merge: take upstream manifest as base, re-apply our local custom fields
python3 - <<PY
import json, datetime, pathlib
local = json.load(open("$TMPDIR/manifest.local.json"))
upstream = json.load(open("$DEST/manifest.json"))
# Preserve everything from upstream, then re-apply our local override fields
for k in ("name", "version", "documentation", "issue_tracker", "requirements"):
    if k in local:
        upstream[k] = local[k]
# Note: 'requirements' is preserved from local to keep our forecast-solar pin
# (currently 5.0.0 to match HA stable's aiohttp 3.13.x). Bump locally if/when
# upstream HA core ships a newer aiohttp.
# Bump the date in version
import re
m = re.match(r"(\d+\.\d+\.\d+)-pr(\d+)\.\d+", upstream.get("version",""))
if m:
    today = datetime.datetime.utcnow().strftime("%Y%m%d")
    upstream["version"] = f"{m.group(1)}-pr{m.group(2)}.{today}"
json.dump(upstream, open("$DEST/manifest.json", "w"), indent=2)
print("Updated manifest:", upstream)
PY

echo ""
echo "Done. PR HEAD was $PR_SHA"
echo "Review with:  git -C $REPO_ROOT diff custom_components/forecast_solar/"

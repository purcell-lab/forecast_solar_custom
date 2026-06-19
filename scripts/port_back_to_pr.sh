#!/usr/bin/env bash
# Generate a patch from this repo's custom_components/forecast_solar/
# that can be applied on top of the PR branch's homeassistant/components/forecast_solar/.
#
# Usage:
#   scripts/port_back_to_pr.sh [/path/to/local/clone/of/purcell-lab/core]
#
# If the path is provided, the patch is applied directly to that clone.
# Otherwise the patch is written to stdout for inspection.
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
SRC="$REPO_ROOT/custom_components/forecast_solar"
CORE_CLONE="${1:-}"

if [[ -n "$CORE_CLONE" ]]; then
  if [[ ! -d "$CORE_CLONE/.git" ]]; then
    echo "ERROR: $CORE_CLONE is not a git repo." >&2
    exit 1
  fi
  DEST="$CORE_CLONE/homeassistant/components/forecast_solar"
  if [[ ! -d "$DEST" ]]; then
    echo "ERROR: $DEST does not exist. Are you on the right branch?" >&2
    exit 1
  fi
  echo "Porting $SRC -> $DEST" >&2

  # Copy everything except manifest.json (custom name/version must not pollute the PR)
  rsync -a --delete \
    --exclude '__pycache__' \
    --exclude 'manifest.json' \
    "$SRC/" "$DEST/"

  # For manifest.json, port only fields that are NOT our local customizations.
  # In practice the PR's manifest is whatever upstream wants; we drop our custom suffixes here.
  python3 - <<PY
import json
ours = json.load(open("$SRC/manifest.json"))
theirs = json.load(open("$DEST/manifest.json"))
# Port over non-custom fields. Skip name (custom), version (custom), documentation (custom), issue_tracker (custom).
SKIP = {"name", "version", "documentation", "issue_tracker"}
changed = False
for k, v in ours.items():
    if k in SKIP:
        continue
    if theirs.get(k) != v:
        theirs[k] = v
        changed = True
# Also handle removals: if a non-SKIP key is in theirs but not in ours, drop it.
for k in list(theirs.keys()):
    if k in SKIP:
        continue
    if k not in ours:
        del theirs[k]
        changed = True
if changed:
    json.dump(theirs, open("$DEST/manifest.json", "w"), indent=2)
    print("Updated $DEST/manifest.json")
else:
    print("manifest.json unchanged")
PY

  cd "$CORE_CLONE"
  echo "" >&2
  echo "Changes staged in $CORE_CLONE. Review with:" >&2
  echo "  git -C $CORE_CLONE diff homeassistant/components/forecast_solar/" >&2
  echo "Then commit and push to the PR branch:" >&2
  echo "  git -C $CORE_CLONE add homeassistant/components/forecast_solar/" >&2
  echo "  git -C $CORE_CLONE commit -m 'port from custom-component testing: <describe>'" >&2
  echo "  git -C $CORE_CLONE push" >&2
else
  # Patch to stdout
  echo "# No CORE_CLONE path given; printing files for manual review." >&2
  echo "# Files in $SRC (excluding manifest.json):"
  find "$SRC" -type f -not -name manifest.json | sort
fi

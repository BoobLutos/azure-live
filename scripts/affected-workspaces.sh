#!/usr/bin/env bash
# Prints `workspaces=<JSON array>` for $GITHUB_OUTPUT: the HCP workspaces a
# change affects, in apply order (from .github/hcp-workspaces.json).
#
# Env:
#   REQUESTED  space-separated workspace names, or "all" (workflow_dispatch)
#   BASE, HEAD commits to diff (pull request: base/head; push: before/after)
set -euo pipefail

map=".github/hcp-workspaces.json"
all="$(jq -c '[.workspaces[].name]' "$map")"

if [[ -n "${REQUESTED:-}" ]]; then
  if [[ "$REQUESTED" == "all" ]]; then
    echo "workspaces=$all"
    exit 0
  fi
  # Keep apply order; reject unknown names.
  requested="$(jq -Rc 'split(" ") | map(select(length > 0))' <<< "$REQUESTED")"
  unknown="$(jq -nc --argjson r "$requested" --argjson a "$all" '$r - $a')"
  if [[ "$unknown" != "[]" ]]; then
    echo "Unknown workspace(s): $unknown" >&2
    exit 1
  fi
  echo "workspaces=$(jq -nc --argjson r "$requested" --argjson a "$all" '[$a[] | select(. as $w | $r | index($w))]')"
  exit 0
fi

# A new branch or a missing base: treat everything as changed.
if [[ -z "${BASE:-}" || "$BASE" =~ ^0+$ ]] || ! git cat-file -e "${BASE}^{commit}" 2>/dev/null; then
  echo "workspaces=$all"
  exit 0
fi

changed="$(git diff --name-only "$BASE" "${HEAD:-HEAD}" | jq -Rc '[., inputs]' 2>/dev/null || echo '[]')"
[[ -z "$changed" ]] && changed='[]'

echo "workspaces=$(jq -c --argjson changed "$changed" '
  [ .workspaces[]
    | select(.paths as $p | any($changed[]; . as $f | any($p[]; . as $prefix | $f | startswith($prefix))))
    | .name ]' "$map")"

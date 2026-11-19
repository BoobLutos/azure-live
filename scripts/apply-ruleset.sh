#!/usr/bin/env bash
# Creates or updates the protect-main ruleset from .github/rulesets/protect-main.json.
# GitHub Free enforces rulesets on public repositories only, so azure-live is public.
# Needs: gh (authenticated as the repo owner), jq. Run from the repo root.
set -euo pipefail

repo="${1:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"
file=".github/rulesets/protect-main.json"
name="$(jq -r .name "$file")"

existing_id="$(gh api "repos/${repo}/rulesets" --jq ".[] | select(.name == \"${name}\") | .id" || true)"

if [[ -n "$existing_id" ]]; then
  echo "Updating ruleset ${name} (${existing_id}) on ${repo}"
  gh api --method PUT "repos/${repo}/rulesets/${existing_id}" --input "$file" > /dev/null
else
  echo "Creating ruleset ${name} on ${repo}"
  gh api --method POST "repos/${repo}/rulesets" --input "$file" > /dev/null
fi

gh api "repos/${repo}/rulesets" --jq '.[] | "\(.name)\t\(.enforcement)"'

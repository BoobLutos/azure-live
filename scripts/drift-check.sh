#!/usr/bin/env bash
# Nightly drift check: queues a plan-only run in each workspace (one at a time,
# the free tier allows one concurrent run), waits for it, and reports any
# workspace whose plan has changes or that errored.
#
# Plan-only runs use the plan identity (Reader), so this can never change Azure.
#
# Env: TFE_TOKEN (team or user token that can queue runs), HCP_ORG,
#      WORKSPACES (space-separated), REPORT (file to write the markdown report to).
set -euo pipefail

: "${TFE_TOKEN:?TFE_TOKEN is required}"
: "${HCP_ORG:?HCP_ORG is required}"
: "${WORKSPACES:?WORKSPACES is required}"
REPORT="${REPORT:-drift-report.md}"
API="https://app.terraform.io/api/v2"
TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-1200}"

api() { # method path [body]
  local method=$1 path=$2 body=${3:-}
  curl -sS --fail-with-body -X "$method" \
    -H "Authorization: Bearer ${TFE_TOKEN}" \
    -H "Content-Type: application/vnd.api+json" \
    ${body:+--data "$body"} \
    "${API}${path}"
}

final_states=" planned_and_finished applied errored canceled force_canceled discarded policy_soft_failed "
drifted=0
{
  echo "| Workspace | Result | + | ~ | - | Run |"
  echo "|---|---|---|---|---|---|"
} > "$REPORT"

for ws in $WORKSPACES; do
  ws_id="$(api GET "/organizations/${HCP_ORG}/workspaces/${ws}" | jq -r .data.id)"

  body="$(jq -n --arg ws "$ws_id" '{
    data: {
      type: "runs",
      attributes: { "plan-only": true, message: "Nightly drift check (GitHub Actions)" },
      relationships: { workspace: { data: { type: "workspaces", id: $ws } } }
    }
  }')"
  run_id="$(api POST "/runs" "$body" | jq -r .data.id)"
  run_url="https://app.terraform.io/app/${HCP_ORG}/workspaces/${ws}/runs/${run_id}"
  echo "${ws}: queued ${run_id}"

  status="pending"
  waited=0
  until [[ "$final_states" == *" ${status} "* ]]; do
    if (( waited >= TIMEOUT_SECONDS )); then status="timeout"; break; fi
    sleep 15
    waited=$(( waited + 15 ))
    status="$(api GET "/runs/${run_id}" | jq -r .data.attributes.status)"
  done
  echo "${ws}: ${status}"

  if [[ "$status" == "planned_and_finished" ]]; then
    plan="$(api GET "/runs/${run_id}/plan" | jq .data.attributes)"
    add="$(jq -r '."resource-additions" // 0' <<< "$plan")"
    chg="$(jq -r '."resource-changes" // 0' <<< "$plan")"
    del="$(jq -r '."resource-destructions" // 0' <<< "$plan")"
    if (( add + chg + del > 0 )); then
      result="drift"
      drifted=1
    else
      result="in sync"
    fi
  else
    add="-"; chg="-"; del="-"
    result="${status}"
    drifted=1
  fi

  echo "| ${ws} | ${result} | ${add} | ${chg} | ${del} | [${run_id}](${run_url}) |" >> "$REPORT"
done

cat "$REPORT"
exit "$drifted"

# azure-live

Live configuration for a multi-environment Azure landing zone, deployed through
VCS-driven HCP Terraform workspaces. Each folder below is the working directory
of exactly one workspace.

| Folder | HCP workspace | Subscription | Apply |
|---|---|---|---|
| `platform/governance` | plat-governance | (management groups at `alz`) | Confirm |
| `platform/management` | plat-management | management | Confirm |
| `platform/connectivity` | plat-connectivity | connectivity | Confirm |
| `landingzones/dev/baseline` | lz-dev-baseline | lz_dev | Auto |
| `landingzones/dev/network` | lz-dev-network | lz_dev | Auto |
| `landingzones/prod/baseline` | lz-prod-baseline | lz_prod | Confirm |
| `landingzones/prod/network` | lz-prod-network | lz_prod | Confirm |

A merged change in a folder queues a run only in that folder's workspace. A
successful apply then triggers the next workspace in the chain:
governance → management → connectivity → {dev, prod} baseline → network.

## How a change flows

1. Branch from a freshly pulled `main`, change, open a pull request.
2. GitHub Actions `pr-checks`: `terraform` (fmt, validate, tflint), `policy-tests`
   (OPA unit tests), `secrets` (gitleaks).
3. GitHub Actions `hcp-runs` uploads the code to every affected HCP workspace
   as a speculative plan (Reader identity, mandatory `alz-guardrails` policy)
   and comments each plan on the PR. `hcp-plans` sums them up.
4. All four checks are required by the `protect-main` ruleset. Merge with
   squash; history stays linear.
5. On merge, `hcp-runs` uploads the code again and starts a run in each affected
   workspace, in apply order. Dev applies automatically; platform and prod wait
   for **Confirm & apply** in HCP. Confirm upstream workspaces first
   (management before connectivity before the spokes).
6. Every night, `drift-check` queues plan-only runs and opens a `drift` issue if
   live Azure differs from `main`.

Which workspaces a change affects is defined once, in
`.github/hcp-workspaces.json`. To re-run workspaces by hand: Actions →
`hcp-runs` → Run workflow (names, or `all`).

Why uploads instead of HCP pulling from GitHub: see decision 12.

## Guardrails (three layers)

| Layer | Where | What it stops |
|---|---|---|
| Azure Policy | Azure, at the `alz` management group | Anything, however it's created (portal, CLI, Terraform) |
| OPA `alz-guardrails` | HCP Terraform, every plan | A Terraform change before it reaches Azure |
| OPA unit tests | GitHub Actions | A broken or weakened guardrail before it's merged |

Phase 1 rules: no Firewall, Bastion, gateways, DDoS plan, Application Gateway,
NAT gateway, public IPs or AKS; Sweden Central only; `env`, `owner` and `phase`
tags; Defender plans on Free; Log Analytics capped at 0.15 GB/day and 30 days.

In Azure Policy these are `Enforce-Locations`, `Enforce-RG-Locations`,
`Deny-Costly-Resources` and `Require-RG-Tags` at `alz`, all enforced. The
upstream Azure landing zones assignments are deployed report-only; see
[lib/README.md](lib/README.md) for what was kept, what was left out and how to
start enforcing.

### Management groups

```
Tenant Root Group
└── alz                       Enforce-Locations, Enforce-RG-Locations, Deny-Costly-Resources, Require-RG-Tags
    ├── platform
    │   ├── management        sub-platform-management-001
    │   ├── connectivity      sub-platform-connectivity-001
    │   └── identity
    ├── landingzones
    │   ├── corp              sub-lz-corp-dev-001, sub-lz-corp-prod-001
    │   └── online
    ├── sandbox               Azure subscription 1
    └── decommissioned
```

## Every subscription's baseline

`modules/subscription-baseline` gives each subscription a monthly budget (alerts
at 50/80/100% actual and 100% forecast), activity-log export to the central Log
Analytics workspace, a Service Health alert, and Defender for Cloud plans pinned
to Free. Budgets: management, connectivity and sandbox 2, dev 5, prod 10.

| Subscription | Applied by |
|---|---|
| management, sandbox | plat-management |
| connectivity | plat-connectivity |
| lz_dev / lz_prod | lz-dev-baseline / lz-prod-baseline |

`modules/platform-conventions` holds the names and IDs several workspaces need
(region, central workspace ID), so no workspace reads another's state.

## Secrets and identifiers

There are none in this repo. Azure sign-in is OIDC (HCP dynamic credentials).
Tenant, subscription and client IDs live in the HCP variable set
`azure-alz-common`, and so does the alert address (`TF_VAR_alert_email`,
sensitive). The only GitHub secret is `TFE_TOKEN` (an Actions secret and, for Dependabot
PRs, a Dependabot secret), used by `hcp-runs` and the drift check.

## Repository settings (one-time)

- Repository variable `HCP_ORG` and secret `TFE_TOKEN` (an owners-team API token;
  organization tokens can't queue runs).
- Ruleset: `scripts/apply-ruleset.sh` (needs `gh` signed in as the owner).
- Squash merging only: Settings → General → Pull Requests.

## Layout

```
platform/ landingzones/   workspace folders (one per HCP workspace)
modules/                  local modules shared by the workspaces
lib/                      ALZ library overrides (archetypes, policy assignments)
policies/opa/             guardrails.rego + unit tests
scripts/                  ruleset and drift-check helpers
docs/decisions.md         why things are the way they are
```

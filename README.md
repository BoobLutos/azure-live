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

1. Branch, change, open a pull request.
2. GitHub Actions (`pr-checks`): `terraform` (fmt, validate, tflint), `policy-tests`
   (OPA unit tests), `secrets` (gitleaks). All three are required by the
   `protect-main` ruleset.
3. HCP Terraform runs a speculative plan for every affected workspace, signed in
   with the Reader identity, and checks it against the mandatory `alz-guardrails`
   policy. Results appear as status checks on the pull request.
4. Merge (squash or rebase; history stays linear). Dev applies automatically;
   platform and prod wait for **Confirm & apply** in HCP.
5. Every night, `drift-check` queues plan-only runs and opens a `drift` issue if
   live Azure differs from `main`.

## Guardrails (three layers)

| Layer | Where | What it stops |
|---|---|---|
| Azure Policy | Azure, at the `alz` management group | Anything, however it's created (portal, CLI, Terraform) |
| OPA `alz-guardrails` | HCP Terraform, every plan | A Terraform change before it reaches Azure |
| OPA unit tests | GitHub Actions | A broken or weakened guardrail before it's merged |

Phase 1 rules: no Firewall, Bastion, gateways, DDoS plan, Application Gateway,
NAT gateway, public IPs or AKS; Sweden Central only; `env`, `owner` and `phase`
tags; Defender plans on Free; Log Analytics capped at 0.15 GB/day and 30 days.

## Secrets and identifiers

There are none in this repo. Azure sign-in is OIDC (HCP dynamic credentials).
Tenant, subscription and client IDs live in the HCP variable set
`azure-alz-common`. The only GitHub secret is `TFE_TOKEN`, used by the drift check.

## Repository settings (one-time)

- Repository variable `HCP_ORG` and secret `TFE_TOKEN` (an owners-team API token;
  organization tokens can't queue runs).
- Ruleset: `scripts/apply-ruleset.sh` (needs `gh` signed in as the owner).
- Squash merging only: Settings → General → Pull Requests.

## Layout

```
platform/ landingzones/   workspace folders (one per HCP workspace)
lib/                      ALZ library overrides (archetypes, policy assignments)
policies/opa/             guardrails.rego + unit tests
scripts/                  ruleset and drift-check helpers
docs/decisions.md         why things are the way they are
```

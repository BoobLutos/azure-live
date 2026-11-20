# ALZ library overrides

`plat-governance` uses the Azure Verified Module `avm-ptn-alz` with the
upstream Azure landing zones library (`platform/alz`, pinned in
`platform/governance/providers.tf`). This folder is a second, local library
loaded on top of it. Policy JSON is never edited in Terraform.

## Why a trimmed library

The upstream root archetype ships 149 policy definitions, 44 initiatives and
5 role definitions, close to 200 resources before a single assignment. The HCP
Terraform free tier counts 500 managed resources for the whole organization, and
many upstream assignments deploy agents, Defender plans or DDoS protection that
cost money or need resources that don't exist yet. So the `*_lite` archetypes
keep only what Phase 1 can use, and deploy only the definitions those
assignments need.

## Files

| File | What |
|---|---|
| `alz_lite.alz_architecture_definition.json` | The hierarchy. `alz` is marked `exists` (bootstrap created it); everything below is created here. |
| `*_lite.alz_archetype_definition.json` | Trimmed archetypes. `management`, `online`, `sandbox` and `decommissioned` use the upstream archetypes unchanged. |
| `Enforce-Locations`, `Enforce-RG-Locations`, `Deny-Costly-Resources`, `Require-RG-Tags` | Our own guardrails, assigned at `alz` and enforced. |
| `Require-RG-Tags.alz_policy_set_definition.json` | Initiative: built-in "Require a tag on resource groups" for env, owner, phase. |

## What was left out, and when it comes back

| Upstream content | Why not now | Phase |
|---|---|---|
| Defender for Cloud plan configuration (`Deploy-MDFC-*`) | Turns on paid Defender plans | Optional, time-boxed trial |
| `Enable-DDoS-VNET` | Needs a paid DDoS protection plan | Not planned |
| Activity log, diagnostics, VM/AMA monitoring, change tracking | Need the Log Analytics workspace and data collection rules | 2 |
| `Deploy-Private-DNS-Zones`, `Audit-PeDnsZones` | Need private DNS zones in connectivity | 3 |
| MCSB initiative at management-group level | Defender for Cloud already assigns MCSB to every subscription (free CSPM) | 2, if wanted |
| Service-specific guardrails (`Enforce-GR-*` except Key Vault), SQL, backup, ASR, TLS | No such services yet; each adds resources | When the service arrives |

## Changing policy

- Start enforcing an upstream assignment: remove it from `report_only` in
  `platform/governance/main.tf`.
- Add or remove an assignment: edit the archetype file here. Any definition or
  initiative it needs must be listed in `root_lite`.
- Bump the upstream library: change `ref` in `providers.tf` and read the plan
  carefully; library releases can rename assignments.

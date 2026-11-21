# Decisions

Short records of choices that shape this landing zone. Newest last.

## 1. One subscription per platform function and environment

Four subscriptions (management, connectivity, lz-dev, lz-prod) plus the original
free-account subscription as sandbox. Environments are subscriptions under the
same archetype, not separate management groups, following Azure landing zone
guidance; prod gets stricter assignments at subscription scope.
*Constraint found:* MCA accounts bought on Azure.com can create one subscription
per 24 hours and five in total, so creation was staggered over four days.

## 2. No stored secrets; OIDC everywhere

HCP Terraform dynamic credentials sign in to Entra ID per run phase. Plan runs
(including pull-request plans and the drift check) use one Reader identity; apply
runs use one identity per blast radius. GitHub Actions has no Azure access at
all. Bootstrap is the only thing run as a human, from Cloud Shell, because new
tenants block device-code sign-in under security defaults.

## 3. Least-privilege apply identities

Governance is Owner at the `alz` management group (needed to assign roles to
policy managed identities). Platform workspaces are Contributor on their own
subscription. Landing-zone identities add RBAC Administrator with a condition
that blocks granting or removing Owner, User Access Administrator and RBAC
Administrator.

## 4. Policy in three layers

The HCP free tier allows one mandatory policy, so all OPA rules are bundled
into one file. Azure Policy carries the authoritative rules inside Azure; OPA
fails plans earlier with clearer messages; CI unit-tests the OPA rules.

## 5. Cost guardrails before resources

Budgets alert but don't stop spending, and cost data lags by hours, so prevention
comes first: blocked expensive types, a single region, Defender on Free, a capped
Log Analytics workspace. Each later phase lifts a block in a reviewed pull request.

## 6. Platform and prod need confirmation; dev applies automatically

The platform has no dev copy; a governance change affects every subscription.

## 7. Azure landing zones via AVM, with a trimmed local library

`avm-ptn-alz` with the upstream library keeps the hierarchy and policy content
aligned with Microsoft's reference. The upstream root archetype alone is about
200 resources and assumes paid services, so a local library (`lib/`) defines
`*_lite` archetypes with only the content Phase 1 can use. Bootstrap owns the
`alz` group; the architecture marks it `exists` and builds everything below it.

## 8. Upstream policies start report-only

Upstream ALZ assignments are deployed with `enforcementMode: DoNotEnforce`:
they report compliance but block nothing. Each is switched to enforcing in its
own pull request once its compliance results have been reviewed. Our own
guardrails (location, costly types, resource-group tags) enforce from day one.

## 9. Tag enforcement on resource groups only

Azure Policy denies resource groups without `env`, `owner` and `phase`. Tags on
individual resources are checked by OPA for anything Terraform creates.
Enforcing tags on every resource in Azure Policy would block resources that
Azure services create on their own. Known side effect: Azure can no longer
auto-create `NetworkWatcherRG`, so Network Watcher is created explicitly (with
tags) in the connectivity workspace. AKS node resource groups need the same
attention in Phase 3.

## 10. Each subscription's baseline is applied by its own workspace

Budgets, activity-log export, Service Health alerts and Defender pins live in one
local module, called by the workspace that owns the subscription. Each
subscription gets its own action group, so no alert depends on another
subscription. Budgets email the alert address directly. The only
cross-subscription link is the activity-log export to the central workspace:
bootstrap grants the connectivity and landing-zone identities a custom role
with just `workspaces/read` and `workspaces/sharedKeys/action` on the
management subscription. Shared names and IDs come from
`modules/platform-conventions` rather than from another workspace's state.

## 11. Resource providers are registered at apply time

The plan identity is Reader and can't register providers, so registration is an
`azapi_resource_action` (POST `.../register`) that only runs during apply. The
azurerm provider has automatic registration switched off.

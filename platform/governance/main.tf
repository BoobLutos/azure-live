# plat-governance: management groups, Azure Policy and subscription placement
# under the existing intermediate root `alz` (created by bootstrap).
#
# Architecture and archetypes: lib/alz_lite.alz_architecture_definition.json
# and lib/*_lite.alz_archetype_definition.json.

locals {
  location = "swedencentral"

  # Upstream ALZ assignments start report-only (DoNotEnforce): they evaluate and
  # report compliance but block nothing. Remove a name from this map in a pull
  # request to start enforcing it. Our own guardrails (Enforce-Locations,
  # Enforce-RG-Locations, Deny-Costly-Resources, Require-RG-Tags) are not listed,
  # so they are enforced from day one.
  report_only = {
    alz            = ["Deny-Classic-Resources", "Deny-UnmanagedDisk", "Audit-ResourceRGLocation", "Audit-UnusedResources"]
    platform       = ["Enforce-GR-KeyVault"]
    identity       = ["Deny-MgmtPorts-Internet", "Deny-Public-IP", "Deny-Subnet-Without-Nsg"]
    landingzones   = ["Deny-IP-forwarding", "Deny-MgmtPorts-Internet", "Deny-Subnet-Without-Nsg", "Deny-Storage-http", "Deny-Priv-Esc-AKS", "Deny-Privileged-AKS", "Enforce-AKS-HTTPS", "Enforce-GR-KeyVault"]
    corp           = ["Deny-HybridNetworking", "Deny-Public-Endpoints", "Deny-Public-IP-On-NIC"]
    sandbox        = ["Enforce-ALZ-Sandbox"]
    decommissioned = ["Enforce-ALZ-Decomm"]
  }

  policy_assignments_to_modify = {
    for mg, assignments in local.report_only : mg => {
      policy_assignments = {
        for name in assignments : name => { enforcement_mode = "DoNotEnforce" }
      }
    }
  }

  # Subscription key (from the azure-alz-common variable set) => management group.
  placement = {
    management   = "management"
    connectivity = "connectivity"
    lz_dev       = "corp"
    lz_prod      = "corp"
    sandbox      = "sandbox"
  }
}

data "azapi_client_config" "current" {}

module "alz" {
  source  = "Azure/avm-ptn-alz/azurerm"
  version = "0.23.0"

  architecture_name  = "alz_lite"
  location           = local.location
  parent_resource_id = data.azapi_client_config.current.tenant_id # parent of the existing alz group
  enable_telemetry   = false

  policy_assignments_to_modify = local.policy_assignments_to_modify

  subscription_placement = {
    for key, mg in local.placement : key => {
      subscription_id       = var.subscription_ids[key]
      management_group_name = mg
    } if contains(keys(var.subscription_ids), key)
  }

  # If a placement is removed, move the subscription back to alz rather than
  # the tenant's default group, so it stays under governance.
  subscription_placement_destroy_behavior = "intermediate_root"
}

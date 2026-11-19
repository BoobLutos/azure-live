# Phase 1 guardrails, checked against every Terraform plan.
#
# One policy file with many rules, because the HCP Terraform free tier allows a
# single mandatory policy. The same file runs in two places:
#   - CI (opa test): unit tests in guardrails_test.rego
#   - HCP Terraform: the mandatory OPA policy on every workspace run
#     (query: data.alz.guardrails.deny)
#
# Azure Policy enforces the same intent inside Azure. This layer fails the plan
# before anything reaches Azure, with a clearer message.
package alz.guardrails

import rego.v1

# HCP passes {"plan": <plan JSON>, "run": ...}; opa/conftest get the plan JSON itself.
plan := object.get(input, "plan", input)

# Only resources being created or updated. Deletes are always allowed.
changes contains rc if {
	some rc in plan.resource_changes
	rc.mode == "managed"
	some action in rc.change.actions
	action in {"create", "update"}
}

# --- 1. Expensive resource types are blocked in Phase 1 ----------------------
# Later phases remove entries here through a pull request.
forbidden_types := {
	"azurerm_firewall": "Azure Firewall",
	"azurerm_bastion_host": "Azure Bastion",
	"azurerm_virtual_network_gateway": "VPN/ExpressRoute gateway",
	"azurerm_express_route_circuit": "ExpressRoute circuit",
	"azurerm_network_ddos_protection_plan": "DDoS protection plan",
	"azurerm_application_gateway": "Application Gateway",
	"azurerm_nat_gateway": "NAT gateway",
	"azurerm_public_ip": "Public IP address",
	"azurerm_kubernetes_cluster": "AKS cluster (Phase 3)",
}

# The same, when created through azapi (type is "Provider/type@api-version").
forbidden_arm_types := {
	"microsoft.network/azurefirewalls",
	"microsoft.network/bastionhosts",
	"microsoft.network/virtualnetworkgateways",
	"microsoft.network/expressroutecircuits",
	"microsoft.network/ddosprotectionplans",
	"microsoft.network/applicationgateways",
	"microsoft.network/natgateways",
	"microsoft.network/publicipaddresses",
	"microsoft.containerservice/managedclusters",
}

deny contains msg if {
	some rc in changes
	label := forbidden_types[rc.type]
	msg := sprintf("%s: %s is blocked in Phase 1 (cost guardrail).", [rc.address, label])
}

deny contains msg if {
	some rc in changes
	rc.type == "azapi_resource"
	arm_type := lower(split(rc.change.after.type, "@")[0])
	arm_type in forbidden_arm_types
	msg := sprintf("%s: %s is blocked in Phase 1 (cost guardrail).", [rc.address, arm_type])
}

# --- 2. One region ------------------------------------------------------------
allowed_locations := {"swedencentral"}

deny contains msg if {
	some rc in changes
	location := rc.change.after.location
	is_string(location)
	normalized := lower(replace(location, " ", ""))
	normalized != "global"
	not normalized in allowed_locations
	msg := sprintf("%s: location %q is not allowed; use one of %v.", [rc.address, location, allowed_locations])
}

# --- 3. Required tags on every azurerm resource that supports tags ------------
required_tags := {"env", "owner", "phase"}

tags_of(after) := after.tags if {
	is_object(after.tags)
} else := {}

deny contains msg if {
	some rc in changes
	startswith(rc.type, "azurerm_")
	"tags" in object.keys(rc.change.after)
	present := {key | some key, _ in tags_of(rc.change.after)}
	missing := required_tags - present
	count(missing) > 0
	msg := sprintf("%s: missing required tags %v.", [rc.address, missing])
}

# --- 4. Defender for Cloud plans stay on the free tier ------------------------
deny contains msg if {
	some rc in changes
	rc.type == "azurerm_security_center_subscription_pricing"
	tier := object.get(rc.change.after, "tier", "unknown")
	tier != "Free"
	plan_name := object.get(rc.change.after, "resource_type", "unknown")
	msg := sprintf("%s: Defender plan %v must use tier \"Free\" (got %v).", [rc.address, plan_name, tier])
}

# --- 5. Log Analytics stays inside the free allowance -------------------------
max_daily_quota_gb := 0.15

max_retention_days := 30

deny contains msg if {
	some rc in changes
	rc.type == "azurerm_log_analytics_workspace"
	quota := object.get(rc.change.after, "daily_quota_gb", -1)
	not valid_quota(quota)
	msg := sprintf("%s: daily_quota_gb must be set, above 0 and at most %v (got %v).", [rc.address, max_daily_quota_gb, quota])
}

deny contains msg if {
	some rc in changes
	rc.type == "azurerm_log_analytics_workspace"
	retention := object.get(rc.change.after, "retention_in_days", 30)
	retention > max_retention_days
	msg := sprintf("%s: retention_in_days must be at most %v (got %v).", [rc.address, max_retention_days, retention])
}

valid_quota(quota) if {
	is_number(quota)
	quota > 0
	quota <= max_daily_quota_gb
}

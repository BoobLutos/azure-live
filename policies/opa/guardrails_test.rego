package alz.guardrails_test

import rego.v1

import data.alz.guardrails

# --- helpers ------------------------------------------------------------------
good_tags := {"env": "dev", "owner": "platform", "phase": "1-landing-zone"}

plan_of(changes) := {"resource_changes": changes}

change(type, after) := {
	"address": sprintf("%s.test", [type]),
	"mode": "managed",
	"type": type,
	"change": {"actions": ["create"], "after": after},
}

compliant_rg := change("azurerm_resource_group", {"name": "rg-test", "location": "swedencentral", "tags": good_tags})

# --- baseline -------------------------------------------------------------------
test_compliant_resource_group_allowed if {
	count(guardrails.deny) == 0 with input as plan_of([compliant_rg])
}

test_hcp_wrapped_input_is_read if {
	firewall := change("azurerm_firewall", {"location": "swedencentral", "tags": good_tags})
	count(guardrails.deny) == 1 with input as {"plan": plan_of([firewall]), "run": {}}
}

test_deletes_are_ignored if {
	deleted := {
		"address": "azurerm_firewall.old",
		"mode": "managed",
		"type": "azurerm_firewall",
		"change": {"actions": ["delete"], "after": null},
	}
	count(guardrails.deny) == 0 with input as plan_of([deleted])
}

test_data_sources_are_ignored if {
	data_source := object.union(change("azurerm_firewall", {"location": "westeurope"}), {"mode": "data"})
	count(guardrails.deny) == 0 with input as plan_of([data_source])
}

# --- 1. forbidden types ----------------------------------------------------------
test_firewall_denied if {
	firewall := change("azurerm_firewall", {"location": "swedencentral", "tags": good_tags})
	count(guardrails.deny) == 1 with input as plan_of([firewall])
}

test_public_ip_denied if {
	pip := change("azurerm_public_ip", {"location": "swedencentral", "tags": good_tags})
	count(guardrails.deny) == 1 with input as plan_of([pip])
}

test_azapi_firewall_denied if {
	firewall := change("azapi_resource", {"type": "Microsoft.Network/azureFirewalls@2024-05-01", "location": "swedencentral"})
	count(guardrails.deny) == 1 with input as plan_of([firewall])
}

test_azapi_vnet_allowed if {
	vnet := change("azapi_resource", {"type": "Microsoft.Network/virtualNetworks@2024-05-01", "location": "swedencentral"})
	count(guardrails.deny) == 0 with input as plan_of([vnet])
}

# --- 2. region ---------------------------------------------------------------------
test_other_region_denied if {
	rg := change("azurerm_resource_group", {"name": "rg-test", "location": "westeurope", "tags": good_tags})
	count(guardrails.deny) == 1 with input as plan_of([rg])
}

test_region_display_name_allowed if {
	rg := change("azurerm_resource_group", {"name": "rg-test", "location": "Sweden Central", "tags": good_tags})
	count(guardrails.deny) == 0 with input as plan_of([rg])
}

test_global_location_allowed if {
	zone := change("azurerm_private_dns_zone", {"location": "global", "tags": good_tags})
	count(guardrails.deny) == 0 with input as plan_of([zone])
}

# --- 3. tags -----------------------------------------------------------------------
test_missing_tags_denied if {
	rg := change("azurerm_resource_group", {"name": "rg-test", "location": "swedencentral", "tags": {"env": "dev"}})
	count(guardrails.deny) == 1 with input as plan_of([rg])
}

test_null_tags_denied if {
	rg := change("azurerm_resource_group", {"name": "rg-test", "location": "swedencentral", "tags": null})
	count(guardrails.deny) == 1 with input as plan_of([rg])
}

test_untaggable_resource_allowed if {
	assignment := change("azurerm_role_assignment", {"scope": "/subscriptions/x", "role_definition_name": "Reader"})
	count(guardrails.deny) == 0 with input as plan_of([assignment])
}

# --- 4. Defender -------------------------------------------------------------------
test_defender_standard_denied if {
	pricing := change("azurerm_security_center_subscription_pricing", {"tier": "Standard", "resource_type": "VirtualMachines"})
	count(guardrails.deny) == 1 with input as plan_of([pricing])
}

test_defender_tier_missing_denied if {
	pricing := change("azurerm_security_center_subscription_pricing", {"resource_type": "VirtualMachines"})
	count(guardrails.deny) == 1 with input as plan_of([pricing])
}

test_defender_free_allowed if {
	pricing := change("azurerm_security_center_subscription_pricing", {"tier": "Free", "resource_type": "VirtualMachines"})
	count(guardrails.deny) == 0 with input as plan_of([pricing])
}

# --- 5. Log Analytics --------------------------------------------------------------
law(after) := change("azurerm_log_analytics_workspace", object.union({"location": "swedencentral", "tags": good_tags}, after))

test_law_capped_allowed if {
	count(guardrails.deny) == 0 with input as plan_of([law({"daily_quota_gb": 0.15, "retention_in_days": 30})])
}

test_law_unlimited_denied if {
	count(guardrails.deny) == 1 with input as plan_of([law({"daily_quota_gb": -1, "retention_in_days": 30})])
}

test_law_quota_missing_denied if {
	count(guardrails.deny) == 1 with input as plan_of([law({"retention_in_days": 30})])
}

test_law_quota_too_high_denied if {
	count(guardrails.deny) == 1 with input as plan_of([law({"daily_quota_gb": 1, "retention_in_days": 30})])
}

test_law_long_retention_denied if {
	count(guardrails.deny) == 1 with input as plan_of([law({"daily_quota_gb": 0.1, "retention_in_days": 90})])
}

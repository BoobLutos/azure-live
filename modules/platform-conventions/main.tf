# Single source of truth for names and IDs that more than one workspace needs.
# No resources: other workspaces compute IDs from here instead of reading
# another workspace's state.

terraform {
  required_version = ">= 1.11"
}

variable "management_subscription_id" {
  description = "Subscription ID of sub-platform-management-001."
  type        = string
}

locals {
  location       = "swedencentral"
  location_short = "swc"

  monitor_resource_group_name = "rg-mgmt-monitor-${local.location_short}"
  log_analytics_name          = "log-alz-mgmt-${local.location_short}"
}

output "location" {
  description = "The one region the landing zone uses."
  value       = local.location
}

output "location_short" {
  description = "Short region code used in names."
  value       = local.location_short
}

output "monitor_resource_group_name" {
  description = "Resource group holding the central Log Analytics workspace."
  value       = local.monitor_resource_group_name
}

output "log_analytics_name" {
  description = "Name of the central Log Analytics workspace."
  value       = local.log_analytics_name
}

output "log_analytics_workspace_id" {
  description = "Resource ID of the central Log Analytics workspace."
  value       = "/subscriptions/${var.management_subscription_id}/resourceGroups/${local.monitor_resource_group_name}/providers/Microsoft.OperationalInsights/workspaces/${local.log_analytics_name}"
}

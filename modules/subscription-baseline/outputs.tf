output "resource_group_name" {
  description = "Baseline resource group in this subscription."
  value       = azurerm_resource_group.baseline.name
}

output "action_group_id" {
  description = "Action group for this subscription's alerts."
  value       = azurerm_monitor_action_group.alerts.id
}

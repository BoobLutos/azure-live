output "log_analytics_workspace_id" {
  description = "Central Log Analytics workspace. Other workspaces compute the same ID through modules/platform-conventions."
  value       = azurerm_log_analytics_workspace.central.id
}

output "log_analytics_id_matches_convention" {
  description = "Guards against drift between the real workspace ID and the conventions module."
  value       = lower(azurerm_log_analytics_workspace.central.id) == lower(module.conventions.log_analytics_workspace_id)
}

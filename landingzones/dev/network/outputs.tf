output "signed_in_as" {
  description = "Client ID of the identity this run used (plan: Reader, apply: workspace identity)."
  value       = data.azurerm_client_config.current.client_id
}

output "subscription_matches" {
  description = "True when ARM_SUBSCRIPTION_ID matches this workspace's entry in subscription_ids."
  value       = data.azurerm_client_config.current.subscription_id == var.subscription_ids[local.subscription_key]
}

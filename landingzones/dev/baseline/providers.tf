# Authentication: HCP Terraform dynamic credentials (OIDC). The plan phase signs
# in with the Reader identity, the apply phase with this workspace's apply
# identity. ARM_TENANT_ID and ARM_SUBSCRIPTION_ID come from HCP variables.
provider "azurerm" {
  features {}
  resource_provider_registrations = "none"
}

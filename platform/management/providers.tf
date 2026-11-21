# Authentication: HCP Terraform dynamic credentials (OIDC). The plan phase signs
# in with the Reader identity, the apply phase with sp-hcp-alz-apply-management.
# ARM_TENANT_ID and ARM_SUBSCRIPTION_ID (management) come from HCP variables.
provider "azurerm" {
  features {}
  resource_provider_registrations = "none"
}

# Same identity, sandbox subscription (bootstrap grants it Contributor there).
provider "azurerm" {
  alias = "sandbox"
  features {}
  subscription_id                 = var.subscription_ids["sandbox"]
  resource_provider_registrations = "none"
}

provider "azapi" {}

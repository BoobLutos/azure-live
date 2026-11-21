terraform {
  required_version = ">= 1.11"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.0, < 6.0"
    }
    azapi = {
      source  = "Azure/azapi"
      version = ">= 2.0, < 3.0"
    }
  }

  # No backend or cloud block: this folder is the working directory of the
  # VCS-driven plat-management workspace, which supplies state and credentials.
}

terraform {
  required_version = ">= 1.12, < 2.0" # avm-ptn-alz needs 1.12+

  required_providers {
    alz = {
      source  = "azure/alz"
      version = "~> 0.22"
    }
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.12"
    }
  }

  # No backend or cloud block: this folder is the working directory of the
  # VCS-driven plat-governance workspace, which supplies state and credentials.
}

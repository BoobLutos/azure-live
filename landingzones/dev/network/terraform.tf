terraform {
  required_version = ">= 1.11"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.0, < 6.0"
    }
  }

  # No backend or cloud block: this folder is the working directory of a
  # VCS-driven HCP Terraform workspace, which supplies state and credentials.
}

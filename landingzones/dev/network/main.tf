# lz-dev-network: dev spoke virtual network and peering to the hub.
#
# Heartbeat only: no resources yet. Proves the workspace signs in to Azure and
# targets the subscription it should.

locals {
  subscription_key = "lz_dev"
}

data "azurerm_client_config" "current" {}

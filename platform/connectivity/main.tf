# plat-connectivity: hub virtual network, NSGs, route tables.
#
# Heartbeat only: no resources yet. Proves the workspace signs in to Azure and
# targets the subscription it should.

locals {
  subscription_key = "connectivity"
}

data "azurerm_client_config" "current" {}

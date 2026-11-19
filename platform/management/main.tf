# plat-management: Log Analytics workspace, action groups, activity-log export.
#
# Heartbeat only: no resources yet. Proves the workspace signs in to Azure and
# targets the subscription it should.

locals {
  subscription_key = "management"
}

data "azurerm_client_config" "current" {}

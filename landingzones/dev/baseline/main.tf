# lz-dev-baseline: budget, Defender plan tiers, tags, activity-log export for dev.
#
# Heartbeat only: no resources yet. Proves the workspace signs in to Azure and
# targets the subscription it should.

locals {
  subscription_key = "lz_dev"
}

data "azurerm_client_config" "current" {}

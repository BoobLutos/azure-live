# plat-management: central Log Analytics workspace, plus the subscription
# baseline (budget, activity-log export, Service Health alert, Defender Free)
# for the management and sandbox subscriptions.

module "conventions" {
  source = "../../modules/platform-conventions"

  management_subscription_id = var.subscription_ids["management"]
}

locals {
  platform_tags = {
    env   = "platform"
    owner = "platform"
    phase = "1-landing-zone"
  }
}

resource "azapi_resource_action" "operational_insights" {
  type        = "Microsoft.Resources/subscriptions@2021-04-01"
  resource_id = "/subscriptions/${var.subscription_ids["management"]}"
  action      = "providers/Microsoft.OperationalInsights/register"
  method      = "POST"
}

resource "azurerm_resource_group" "monitor" {
  name     = module.conventions.monitor_resource_group_name
  location = module.conventions.location
  tags     = local.platform_tags
}

# Stays inside the free allowance (5 GB per billing account per month, 31 days
# interactive retention). The OPA guardrail enforces both limits.
resource "azurerm_log_analytics_workspace" "central" {
  name                = module.conventions.log_analytics_name
  location            = azurerm_resource_group.monitor.location
  resource_group_name = azurerm_resource_group.monitor.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  daily_quota_gb      = 0.15
  tags                = local.platform_tags

  depends_on = [azapi_resource_action.operational_insights]
}

module "baseline_management" {
  source = "../../modules/subscription-baseline"

  name                       = "management"
  subscription_id            = var.subscription_ids["management"]
  tags                       = local.platform_tags
  alert_email                = var.alert_email
  budget_amount              = 2
  log_analytics_workspace_id = azurerm_log_analytics_workspace.central.id
}

module "baseline_sandbox" {
  source = "../../modules/subscription-baseline"

  providers = {
    azurerm = azurerm.sandbox
    azapi   = azapi # passed explicitly: a providers map disables implicit inheritance
  }

  name                       = "sandbox"
  subscription_id            = var.subscription_ids["sandbox"]
  tags                       = merge(local.platform_tags, { env = "sandbox" })
  alert_email                = var.alert_email
  budget_amount              = 2
  log_analytics_workspace_id = azurerm_log_analytics_workspace.central.id
}

# Check that activity-log ingestion stays free (run in the workspace's Logs):
#   AzureActivity | summarize GB = sum(_BilledSize) / 1e9 by SubscriptionId, _IsBillable

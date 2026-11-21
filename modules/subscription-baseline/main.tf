# Baseline every subscription gets: budget, activity-log export, Service
# Health alert, Defender plans pinned to Free. Everything here is free to run.

# Registered at apply only (POST action); the Reader plan identity never needs
# register permission. Same pattern as the AVM subscription-vending module.
resource "azapi_resource_action" "resource_provider" {
  for_each = var.resource_providers

  type        = "Microsoft.Resources/subscriptions@2021-04-01"
  resource_id = "/subscriptions/${var.subscription_id}"
  action      = "providers/${each.value}/register"
  method      = "POST"
}

resource "azurerm_resource_group" "baseline" {
  name     = "rg-${var.name}-baseline-swc"
  location = var.location
  tags     = var.tags
}

# --- Cost ---------------------------------------------------------------------
# Budgets alert but don't stop spending, and cost data lags by hours; the
# preventive controls are the Azure Policy and OPA guardrails.
resource "azurerm_consumption_budget_subscription" "monthly" {
  name            = "budget-${var.name}-monthly"
  subscription_id = "/subscriptions/${var.subscription_id}"
  amount          = var.budget_amount
  time_grain      = "Monthly"

  time_period {
    start_date = var.budget_start_date
  }

  dynamic "notification" {
    for_each = {
      actual-50      = { threshold = 50, type = "Actual" }
      actual-80      = { threshold = 80, type = "Actual" }
      actual-100     = { threshold = 100, type = "Actual" }
      forecasted-100 = { threshold = 100, type = "Forecasted" }
    }

    content {
      enabled        = true
      threshold      = notification.value.threshold
      threshold_type = notification.value.type
      operator       = "GreaterThanOrEqualTo"
      contact_emails = [var.alert_email]
    }
  }

  lifecycle {
    ignore_changes = [time_period] # Azure normalises the date format
  }

  depends_on = [azapi_resource_action.resource_provider]
}

# --- Activity log -> central Log Analytics -------------------------------------
# AzureActivity is a free table; check with:
#   AzureActivity | summarize GB = sum(_BilledSize) / 1e9 by _IsBillable
resource "azurerm_monitor_diagnostic_setting" "activity_log" {
  name                       = "diag-activity-to-law"
  target_resource_id         = "/subscriptions/${var.subscription_id}"
  log_analytics_workspace_id = var.log_analytics_workspace_id

  dynamic "enabled_log" {
    for_each = toset(["Administrative", "Security", "ServiceHealth", "Alert", "Recommendation", "Policy", "Autoscale", "ResourceHealth"])

    content {
      category = enabled_log.value
    }
  }

  depends_on = [azapi_resource_action.resource_provider]
}

# --- Alerts --------------------------------------------------------------------
# One action group per subscription keeps every alert inside its own
# subscription (no cross-subscription references).
resource "azurerm_monitor_action_group" "alerts" {
  name                = "ag-${var.name}-alerts"
  resource_group_name = azurerm_resource_group.baseline.name
  short_name          = substr("alz${var.name}", 0, 12)
  location            = "global"
  tags                = var.tags

  email_receiver {
    name                    = "primary"
    email_address           = var.alert_email
    use_common_alert_schema = true
  }

  depends_on = [azapi_resource_action.resource_provider]
}

resource "azurerm_monitor_activity_log_alert" "service_health" {
  name                = "alert-${var.name}-service-health"
  resource_group_name = azurerm_resource_group.baseline.name
  location            = "global"
  scopes              = ["/subscriptions/${var.subscription_id}"]
  description         = "Azure service incidents, maintenance and security advisories affecting this subscription."
  tags                = var.tags

  criteria {
    category = "ServiceHealth"

    service_health {
      locations = ["Global", "Sweden Central"]
    }
  }

  action {
    action_group_id = azurerm_monitor_action_group.alerts.id
  }
}

# --- Defender for Cloud ---------------------------------------------------------
resource "azurerm_security_center_subscription_pricing" "free" {
  for_each = var.defender_plans

  tier          = "Free"
  resource_type = each.value

  depends_on = [azapi_resource_action.resource_provider]
}

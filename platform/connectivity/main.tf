# plat-connectivity: subscription baseline for connectivity. The hub network comes next.

module "conventions" {
  source = "../../modules/platform-conventions"

  management_subscription_id = var.subscription_ids["management"]
}

module "baseline" {
  source = "../../modules/subscription-baseline"

  name            = "connectivity"
  subscription_id = var.subscription_ids["connectivity"]
  tags = {
    env   = "platform"
    owner = "platform"
    phase = "1-landing-zone"
  }
  alert_email   = var.alert_email
  budget_amount = 2

  # Central workspace in the management subscription. Bootstrap grants this
  # workspace's identity the narrow "Log Analytics Workspace Linker" role on it.
  log_analytics_workspace_id = module.conventions.log_analytics_workspace_id
}

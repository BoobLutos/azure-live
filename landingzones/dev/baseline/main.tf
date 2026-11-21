# lz-dev-baseline: subscription baseline for dev (budget, activity-log export, Service Health alert, Defender Free).

module "conventions" {
  source = "../../../modules/platform-conventions"

  management_subscription_id = var.subscription_ids["management"]
}

module "baseline" {
  source = "../../../modules/subscription-baseline"

  name            = "dev"
  subscription_id = var.subscription_ids["lz_dev"]
  tags = {
    env   = "dev"
    owner = "platform"
    phase = "1-landing-zone"
  }
  alert_email   = var.alert_email
  budget_amount = 5

  # Central workspace in the management subscription. Bootstrap grants this
  # workspace's identity the narrow "Log Analytics Workspace Linker" role on it.
  log_analytics_workspace_id = module.conventions.log_analytics_workspace_id
}

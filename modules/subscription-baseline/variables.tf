variable "name" {
  description = "Short name used in resource names, e.g. dev, prod, management."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{2,12}$", var.name))
    error_message = "name must be 2-12 lowercase letters or digits."
  }
}

variable "subscription_id" {
  description = "Subscription the baseline is applied to. Must match the azurerm provider passed to this module."
  type        = string
}

variable "tags" {
  description = "Tags for every taggable resource. Must include env, owner and phase (Azure Policy and OPA require them)."
  type        = map(string)

  validation {
    condition     = alltrue([for t in ["env", "owner", "phase"] : contains(keys(var.tags), t)])
    error_message = "tags must include env, owner and phase."
  }
}

variable "location" {
  description = "Region for the baseline resource group."
  type        = string
  default     = "swedencentral"
}

variable "alert_email" {
  description = "Address that receives budget and Service Health alerts."
  type        = string
  sensitive   = true
}

variable "budget_amount" {
  description = "Monthly budget in the billing currency."
  type        = number

  validation {
    condition     = var.budget_amount > 0
    error_message = "budget_amount must be positive."
  }
}

variable "budget_start_date" {
  description = "First month of the budget (first day of a month, RFC 3339)."
  type        = string
  default     = "2026-11-01T00:00:00Z"
}

variable "log_analytics_workspace_id" {
  description = "Central Log Analytics workspace that receives the subscription's activity log."
  type        = string
}

variable "defender_plans" {
  description = "Defender for Cloud plans pinned to the Free tier, so a portal click can't start a paid plan unnoticed (drift check reports it)."
  type        = set(string)
  default     = ["VirtualMachines", "StorageAccounts", "Containers", "KeyVaults", "Arm", "CloudPosture"]
}

variable "resource_providers" {
  description = "Resource providers registered at apply time (the plan identity is Reader and can't register them)."
  type        = set(string)
  default     = ["Microsoft.Insights", "Microsoft.Security", "Microsoft.Consumption"]
}

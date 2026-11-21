variable "subscription_ids" {
  description = "Subscription IDs by key (management, connectivity, lz_dev, lz_prod, sandbox). Set by the azure-alz-common variable set; never committed."
  type        = map(string)
}

variable "alert_email" {
  description = "Receives budget and Service Health alerts. Set as a sensitive variable in the azure-alz-common variable set."
  type        = string
  sensitive   = true
}

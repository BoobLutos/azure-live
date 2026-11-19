variable "subscription_ids" {
  description = "Subscription IDs by key (management, connectivity, lz_dev, lz_prod, sandbox). Set by the azure-alz-common variable set; never committed."
  type        = map(string)
}
##

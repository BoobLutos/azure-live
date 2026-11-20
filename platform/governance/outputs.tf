output "management_group_resource_ids" {
  description = "Management groups by name."
  value       = module.alz.management_group_resource_ids
}

output "policy_assignment_resource_ids" {
  description = "Policy assignments by management group/name."
  value       = module.alz.policy_assignment_resource_ids
}

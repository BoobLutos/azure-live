# Deliberate violations: wrong region, missing tags. Never merge.
resource "azurerm_resource_group" "guardrail_test" {
  name     = "rg-guardrail-test"
  location = "westeurope"
}

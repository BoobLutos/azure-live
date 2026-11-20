# Authentication: HCP Terraform dynamic credentials (OIDC) through the ARM_*
# environment variables, which both providers read. Plan runs sign in as the
# Reader identity, applies as sp-hcp-alz-apply-governance (Owner at alz).
provider "azapi" {}

# Policy content: the upstream Azure landing zones library, pinned, plus our
# overrides in /lib (trimmed archetypes, report-only content, own guardrails).
# Keep values here known at plan time; unknown values make the provider
# propose replacing everything.
provider "alz" {
  library_references = [
    {
      path = "platform/alz"
      ref  = "2026.11.0"
    },
    {
      custom_url = "${path.root}/../../lib"
    }
  ]
}

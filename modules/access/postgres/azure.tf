# Entra-backed login roles (spec section 11.2). Idempotent: pgaadauth_create_principal_with_oid
# is only called if the role doesn't already exist. Every identifier is
# validated against a strict regex before being interpolated into SQL,
# since these names ultimately come from app-team YAML.
locals {
  azure_identifier_re = "^[a-zA-Z][a-zA-Z0-9_.-]{1,62}$"
}

resource "terraform_data" "validate_azure_identifiers" {
  for_each = var.cloud == "azure" ? local.unique_principals : {}

  lifecycle {
    precondition {
      condition     = can(regex(local.azure_identifier_re, each.value.name))
      error_message = "Principal name '${each.value.name}' does not match the allowed identifier pattern; refusing to interpolate into SQL."
    }
  }

  input = each.value.name
}

resource "terraform_data" "entra_principal" {
  for_each = var.cloud == "azure" ? local.unique_principals : {}

  input = each.value

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    environment = {
      PGHOST     = var.server_fqdn
      PGDATABASE = "postgres"
      PGSSLMODE  = "verify-full"
    }
    command = <<-EOT
      set -euo pipefail
      psql -v ON_ERROR_STOP=1 -tAc "
        SELECT pgaadauth_create_principal_with_oid('${each.value.name}', '${each.value.object_id}', '${each.value.type}', false, false)
        WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '${each.value.name}');"
    EOT
  }

  depends_on = [terraform_data.validate_azure_identifiers]
  # Destroy path is intentionally NOT automated here: dropping a login role
  # requires REASSIGN OWNED / DROP OWNED first. See docs/runbooks/offboard-principal.md.
}

resource "postgresql_grant_role" "azure_bind" {
  for_each = var.cloud == "azure" ? local.principals : {}

  role       = each.value.name
  grant_role = each.value.grant

  depends_on = [terraform_data.entra_principal]
}

include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  server_name   = basename(dirname(get_terragrunt_dir()))
  request_files = fileset("${get_repo_root()}/requests", "**/*.yaml")
  requests = [
    for f in local.request_files : yamldecode(file("${get_repo_root()}/requests/${f}"))
    if !startswith(f, "_") && yamldecode(file("${get_repo_root()}/requests/${f}")).spec.server == local.server_name
  ]
  databases = merge([
    for r in local.requests : {
      for d in r.spec.databases : d.name => {
        team   = r.metadata.team
        access = r.spec.access
      }
    }
  ]...)
}

terraform {
  source = "${get_repo_root()}/modules/access/postgres"
}

dependency "server" {
  config_path = "../10-server"
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = { fqdn = "mock.postgres.database.azure.com" }
}

# See 20-databases/terragrunt.hcl for the AAD-token provider note. L3's
# state is sensitive (ADR 0001) — only the id-dev-l3 pipeline identity and
# the DBA break-glass group can read it.
generate "provider_postgresql" {
  path      = "provider_postgresql.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    provider "postgresql" {
      scheme    = "postgres"
      host      = "${dependency.server.outputs.fqdn}"
      port      = 5432
      database  = "postgres"
      username  = "id-dev-l3"
      password  = "${get_env("PG_AAD_TOKEN", "")}"
      sslmode   = "verify-full"
      superuser = false
    }
  EOF
}

dependency "databases" {
  config_path = "../20-databases"
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = { database_names = {}, group_role_names = {} }
}

inputs = {
  cloud       = "azure"
  databases   = local.databases
  server_fqdn = dependency.server.outputs.fqdn
  tenant_id   = get_env("AZURE_TENANT_ID", "00000000-0000-0000-0000-000000000000")
}

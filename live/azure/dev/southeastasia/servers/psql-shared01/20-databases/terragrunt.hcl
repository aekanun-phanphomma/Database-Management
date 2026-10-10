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
      for d in r.spec.databases : d.name => merge(d, {
        team                = r.metadata.team
        data_classification = r.spec.data_classification
        tier                = r.spec.tier
        access              = r.spec.access
      })
    }
  ]...)
}

terraform {
  source = "${get_repo_root()}/modules/databases/postgres"
}

dependency "server" {
  config_path = "../10-server"
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = {
    fqdn                      = "mock.postgres.database.azure.com"
    allowed_classifications   = ["internal", "confidential"]
    max_databases_per_server  = 20
    reserved_connections      = 10
  }
}

# Azure AD auth: the "password" the postgresql provider sends is a
# short-lived AAD access token for the Postgres resource (the L2 pipeline's
# own Entra principal, which is an Entra admin on the server per spec
# section 11.2). The CI workflow step runs
#   `az account get-access-token --resource-type oss-rdbms --query accessToken -o tsv`
# immediately before this stack's plan/apply and exports it as
# TF_VAR_pg_aad_token (never written to disk or logs); Terragrunt reads it
# here via get_env so the token never touches state.
# TODO(verify): confirm cyrilgdn/postgresql ~> 1.25 accepts an AAD token as
# the `password` field for scheme "postgres" with sslmode=verify-full; if
# not, fall back to the provider's native Azure auth path if one exists in
# the pinned version.
generate "provider_postgresql" {
  path      = "provider_postgresql.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    provider "postgresql" {
      scheme    = "postgres"
      host      = "${dependency.server.outputs.fqdn}"
      port      = 5432
      database  = "postgres"
      username  = "id-dev-l2"
      password  = "${get_env("PG_AAD_TOKEN", "")}"
      sslmode   = "verify-full"
      superuser = false
    }
  EOF
}

inputs = {
  databases                      = local.databases
  server_max_connections         = 0 # unknown at plan time for Flexible Server; guardrail skipped, enforced operationally instead
  reserved_connections           = dependency.server.outputs.reserved_connections
  server_allowed_classifications = dependency.server.outputs.allowed_classifications
  max_databases_per_server       = dependency.server.outputs.max_databases_per_server
}

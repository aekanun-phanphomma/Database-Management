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
  mock_outputs = { address = "mock.rds.amazonaws.com", dbi_resource_id = "db-MOCK" }
}

# This state is sensitive (principal/role bindings) — see ADR 0001.
# Read access is restricted to the L3 pipeline identity + DBA break-glass
# group at the backend/bucket-policy level, not enforced by this file.
generate "provider_postgresql" {
  path      = "provider_postgresql.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    provider "postgresql" {
      scheme             = "awspostgres"
      host               = "${dependency.server.outputs.address}"
      port               = 5432
      database           = "postgres"
      username           = "tf_admin"
      aws_rds_iam_auth   = true
      aws_rds_iam_region = "ap-southeast-1"
      sslmode            = "verify-full"
      superuser          = false
    }
  EOF
}

dependency "databases" {
  config_path = "../20-databases"
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = { database_names = {}, group_role_names = {} }
}

inputs = {
  cloud           = "aws"
  databases       = local.databases
  region          = "ap-southeast-1"
  account_id      = get_env("DEV_AWS_ACCOUNT_ID", "000000000000")
  dbi_resource_id = dependency.server.outputs.dbi_resource_id
}

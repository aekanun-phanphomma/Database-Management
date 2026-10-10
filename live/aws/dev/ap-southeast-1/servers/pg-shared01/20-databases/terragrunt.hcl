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
  # Flatten: one map entry per logical database, keyed by db name (stable key).
  # A duplicate (server, db) pair here is a silent-override bug — CI's
  # scripts/check-duplicates.sh is what actually catches that, not this code.
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

# tf_admin is bootstrapped once per server by a one-time break-glass
# script (docs/runbooks/postgres-bootstrap.md), using the RDS-managed
# master secret ephemerally, exactly as described in ADR 0003 /
# spec section 11.3. Every apply after that authenticates via IAM auth —
# the master secret is never read again.
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

dependency "server" {
  config_path = "../10-server"
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = {
    allowed_classifications  = ["internal", "confidential"]
    max_databases_per_server = 20
    reserved_connections     = 10
    max_connections          = 0
    address                  = "mock.rds.amazonaws.com"
  }
}

inputs = {
  databases                      = local.databases
  server_max_connections         = try(dependency.server.outputs.max_connections, 0)
  reserved_connections           = dependency.server.outputs.reserved_connections
  server_allowed_classifications = dependency.server.outputs.allowed_classifications
  max_databases_per_server       = dependency.server.outputs.max_databases_per_server
}

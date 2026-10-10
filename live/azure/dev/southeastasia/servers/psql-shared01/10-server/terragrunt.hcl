include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_repo_root()}/modules/azure/sql/postgres-flexible"
}

dependency "network" {
  config_path = "${get_repo_root()}/live/azure/dev/southeastasia/00-foundation/network"
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = { delegated_subnet_ids = { "snet-pgflex" = "/subscriptions/mock/.../subnets/snet-pgflex" }, private_dns_zone_ids = { "privatelink.postgres.database.azure.com" = "/subscriptions/mock/.../privateDnsZones/mock" } }
}

dependency "keyvault" {
  config_path = "${get_repo_root()}/live/azure/dev/southeastasia/00-foundation/keyvault"
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = { key_versionless_ids = { postgres = "https://mock.vault.azure.net/keys/mock" } }
}

dependency "observability" {
  config_path = "${get_repo_root()}/live/azure/dev/southeastasia/00-foundation/observability"
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = { log_analytics_workspace_id = "/subscriptions/mock/.../workspaces/mock", action_group_id = "/subscriptions/mock/.../actionGroups/mock" }
}

dependency "backup_policy" {
  config_path = "${get_repo_root()}/live/_shared/backup-policy"
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = { policy = { tier1 = { pitr_retention_days = 35, geo_redundant = true } } }
}

locals {
  tier = "tier1"

  # azure.extensions must be the UNION of extensions requested by every
  # database on this server (spec section 10.2.7) — computed here, at L1,
  # since the server parameter is set once for the whole server, not per
  # database.
  server_name   = basename(dirname(get_terragrunt_dir()))
  request_files = fileset("${get_repo_root()}/requests", "**/*.yaml")
  matching_requests = [
    for f in local.request_files : yamldecode(file("${get_repo_root()}/requests/${f}"))
    if !startswith(f, "_") && yamldecode(file("${get_repo_root()}/requests/${f}")).spec.server == local.server_name
  ]
  allowed_extensions = distinct(flatten([
    for r in local.matching_requests : flatten([for d in r.spec.databases : try(d.extensions, [])])
  ]))
}

inputs = {
  name                = "${get_env("ORG_PREFIX", "acme")}-dev-psql-shared01"
  resource_group_name = get_env("DEV_RG_NAME", "rg-acme-dev-db")
  location              = "southeastasia"
  sku_name              = "GP_Standard_D2s_v3"
  storage_mb            = 131072
  delegated_subnet_id   = dependency.network.outputs.delegated_subnet_ids["snet-pgflex"]
  private_dns_zone_id   = dependency.network.outputs.private_dns_zone_ids["privatelink.postgres.database.azure.com"]
  tenant_id             = get_env("AZURE_TENANT_ID", "00000000-0000-0000-0000-000000000000")
  cmk_identity_id         = get_env("DEV_PG_CMK_IDENTITY_ID", "/subscriptions/TODO/.../userAssignedIdentities/id-pg-cmk")
  cmk_versionless_key_id  = dependency.keyvault.outputs.key_versionless_ids["postgres"]
  tier                    = local.tier
  backup_policy           = dependency.backup_policy.outputs.policy[local.tier]
  dba_group_object_id     = get_env("DBA_GROUP_OID", "00000000-0000-0000-0000-000000000000")
  dba_group_name          = "grp-dba-admins"
  pipeline_l3_object_id   = get_env("DEV_L3_SP_OID", "00000000-0000-0000-0000-000000000000")
  pipeline_l3_name        = "id-dev-l3"
  log_analytics_workspace_id = dependency.observability.outputs.log_analytics_workspace_id
  action_group_id            = dependency.observability.outputs.action_group_id
  allowed_classifications    = ["internal", "confidential"]
  allowed_extensions          = local.allowed_extensions
}

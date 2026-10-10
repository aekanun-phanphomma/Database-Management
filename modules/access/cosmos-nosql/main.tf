# Built-in Cosmos SQL role definition IDs (documented by Microsoft as
# fixed well-known GUIDs, not generated per-account):
#   00000000-0000-0000-0000-000000000001 = Cosmos DB Built-in Data Reader
#   00000000-0000-0000-0000-000000000002 = Cosmos DB Built-in Data Contributor
# TODO(verify): re-confirm these two GUIDs against current Microsoft Learn
# docs before relying on them in a real deployment.
locals {
  cosmos_builtin_roles = {
    ro = "00000000-0000-0000-0000-000000000001"
    rw = "00000000-0000-0000-0000-000000000002"
  }

  # "<db>:<principal>" => { database, object_id, role }
  bindings = merge([
    for db, cfg in var.databases : merge(
      {
        for a in try(cfg.access.apps, []) :
        "${db}:${a.principal}" => { database = db, object_id = a.object_id, role = a.role }
      },
      {
        "${db}:${cfg.access.migration.principal}" = { database = db, object_id = cfg.access.migration.object_id, role = "rw" }
      },
      {
        for e in try(cfg.access.engineers, []) :
        "${db}:${e.group}" => { database = db, object_id = e.object_id, role = e.role == "eng_rw" ? "rw" : "ro" }
      }
    )
  ]...)
}

resource "azurerm_cosmosdb_sql_role_assignment" "this" {
  for_each            = local.bindings
  resource_group_name = var.resource_group_name
  account_name         = var.account_name
  role_definition_id   = "${var.account_id}/sqlRoleDefinitions/${local.cosmos_builtin_roles[each.value.role]}"
  principal_id          = each.value.object_id
  scope                  = "${var.account_id}/dbs/${each.value.database}"
}

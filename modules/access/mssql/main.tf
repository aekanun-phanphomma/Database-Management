# Custom database roles per tier (spec section 11.4). Avoid granting
# built-in db_owner to apps — role_rw/role_ro/role_eng_ro/role_eng_rw are
# scoped to exactly the permissions each tier needs. The migration
# identity is the one principal that DOES get db_owner-equivalent DDL
# rights, via role_owner below.

data "mssql_database" "this" {
  for_each = var.databases
  name     = each.key
}

locals {
  tiers = ["owner", "rw", "ro", "eng_ro", "eng_rw"]

  role_perms = {
    owner  = ["SELECT", "INSERT", "UPDATE", "DELETE", "EXECUTE", "ALTER", "CREATE TABLE", "CREATE VIEW"]
    rw     = ["SELECT", "INSERT", "UPDATE", "DELETE", "EXECUTE"]
    ro     = ["SELECT"]
    eng_ro = ["SELECT"]
    eng_rw = ["SELECT", "INSERT", "UPDATE", "DELETE", "EXECUTE"]
  }

  # "<db>_<tier>" => { database, tier }
  db_roles = merge([
    for db, _ in var.databases : {
      for t in local.tiers : "${db}_${t}" => { database = db, tier = t }
    }
  ]...)

  # "<db>:<principal>" => { database, name, client_id, role }
  bindings = merge([
    for db, cfg in var.databases : merge(
      {
        for a in try(cfg.access.apps, []) :
        "${db}:${a.principal}" => { database = db, name = a.principal, client_id = try(a.object_id, null), role_tier = a.role }
      },
      {
        "${db}:${cfg.access.migration.principal}" = { database = db, name = cfg.access.migration.principal, client_id = try(cfg.access.migration.object_id, null), role_tier = "owner" }
      },
      {
        for e in try(cfg.access.engineers, []) :
        "${db}:${e.group}" => { database = db, name = e.group, client_id = try(e.object_id, null), role_tier = e.role }
      }
    )
  ]...)
}

resource "mssql_database_role" "this" {
  for_each    = local.db_roles
  name        = "role_${each.value.tier}"
  database_id = data.mssql_database.this[each.value.database].id
}

resource "mssql_database_permission" "this" {
  for_each = merge([
    for k, r in local.db_roles : {
      for p in local.role_perms[r.tier] : "${k}:${p}" => { role_key = k, perm = p }
    }
  ]...)

  database_id  = data.mssql_database.this[local.db_roles[each.value.role_key].database].id
  principal_id = mssql_database_role.this[each.value.role_key].id
  permission   = each.value.perm
}

resource "mssql_azuread_service_principal" "app" {
  for_each    = local.bindings
  name        = each.value.name
  client_id   = each.value.client_id
  database_id = data.mssql_database.this[each.value.database].id
}

resource "mssql_database_role_member" "app" {
  for_each  = local.bindings
  role_id   = mssql_database_role.this["${each.value.database}_${each.value.role_tier}"].id
  member_id = mssql_azuread_service_principal.app[each.key].id
}

# MySQL has no cluster-wide role-name collision problem the way Postgres
# does (grants are already scoped to a specific user@host + database), so
# unlike modules/access/postgres this creates per-principal users directly
# rather than NOLOGIN group roles bound afterward.
locals {
  rw_privs = ["SELECT", "INSERT", "UPDATE", "DELETE"]
  ro_privs = ["SELECT"]
  owner_privs = ["ALL PRIVILEGES"]

  # "<db>:<principal>" => { database, name, tier }
  bindings = merge([
    for db, cfg in var.databases : merge(
      { for a in try(cfg.access.apps, []) : "${db}:${a.principal}" => { database = db, name = a.principal, tier = a.role } },
      { "${db}:${cfg.access.migration.principal}" = { database = db, name = cfg.access.migration.principal, tier = "owner" } },
      { for e in try(cfg.access.engineers, []) : "${db}:${e.group}" => { database = db, name = e.group, tier = e.role } }
    )
  ]...)

  tier_privs = {
    rw     = local.rw_privs
    ro     = local.ro_privs
    owner  = local.owner_privs
    eng_ro = local.ro_privs
    eng_rw = local.rw_privs
  }
}

# AWS: IAM-authenticated users (AWSAuthenticationPlugin). Azure: AAD-
# authenticated users once azurerm_mysql_flexible_server supports it
# (see modules/azure/sql/mysql-flexible's TODO) — until then this falls
# back to a rotation-owned secret per ADR 0003 option 3.
# TODO(verify): confirm the exact `auth_plugin`/equivalent argument name
# for the pinned petoju/mysql ~> 3.0 provider version for each cloud's
# identity-auth path.
resource "mysql_user" "this" {
  for_each = local.bindings

  user     = each.value.name
  host     = "%"
  auth_plugin = var.cloud == "aws" ? "AWSAuthenticationPlugin" : null
}

resource "mysql_grant" "this" {
  for_each   = local.bindings
  user       = mysql_user.this[each.key].user
  host       = mysql_user.this[each.key].host
  database   = each.value.database
  privileges = local.tier_privs[each.value.tier]
}

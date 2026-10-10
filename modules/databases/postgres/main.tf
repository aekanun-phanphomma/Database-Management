locals {
  tiers = ["owner", "rw", "ro", "eng_ro", "eng_rw"]

  # "<db>_<tier>" => { database, tier }
  group_roles = merge([
    for db, _ in var.databases : {
      for t in local.tiers : "${db}_${t}" => { database = db, tier = t }
    }
  ]...)

  # "<db>.<schema>" => { database, schema }
  schemas = merge([
    for db, cfg in var.databases : {
      for s in cfg.schemas : "${db}.${s}" => { database = db, schema = s }
    }
  ]...)

  # "<db>.<ext>" => { database, extension }
  extensions = merge([
    for db, cfg in var.databases : {
      for e in cfg.extensions : "${db}.${e}" => { database = db, extension = e }
    }
  ]...)

  table_privs = {
    rw     = ["SELECT", "INSERT", "UPDATE", "DELETE"]
    ro     = ["SELECT"]
    eng_ro = ["SELECT"]
    eng_rw = ["SELECT", "INSERT", "UPDATE", "DELETE"]
  }
  sequence_privs = {
    rw     = ["USAGE", "SELECT", "UPDATE"]
    ro     = ["SELECT"]
    eng_ro = ["SELECT"]
    eng_rw = ["USAGE", "SELECT", "UPDATE"]
  }

  # "<db>.<schema>:<tier>" => {...}  — only for tiers that touch table/sequence privileges (owner excluded; owner already has them via schema ownership)
  schema_tier = merge([
    for k, s in local.schemas : {
      for t, _ in local.table_privs : "${k}:${t}" => merge(s, { tier = t, role = "${s.database}_${t}" })
    }
  ]...)
}

resource "postgresql_role" "group" {
  for_each = local.group_roles
  name     = each.key
  login    = false
  inherit  = true
}

resource "postgresql_database" "this" {
  for_each          = var.databases
  name              = each.key
  owner             = postgresql_role.group["${each.key}_owner"].name
  connection_limit  = each.value.connection_limit
  allow_connections = true

  lifecycle {
    prevent_destroy = true
  }

  depends_on = [terraform_data.guardrails]
}

# Lock the door: nobody connects unless explicitly granted (spec section 10.2).
resource "postgresql_grant" "revoke_public_connect" {
  for_each    = var.databases
  database    = postgresql_database.this[each.key].name
  role        = "public"
  object_type = "database"
  privileges  = []
}

resource "postgresql_grant" "revoke_public_schema" {
  for_each    = var.databases
  database    = postgresql_database.this[each.key].name
  role        = "public"
  schema      = "public"
  object_type = "schema"
  privileges  = []
}

resource "postgresql_grant" "connect" {
  for_each    = local.group_roles
  database    = postgresql_database.this[each.value.database].name
  role        = postgresql_role.group[each.key].name
  object_type = "database"
  privileges  = each.value.tier == "owner" ? ["CONNECT", "CREATE", "TEMPORARY"] : ["CONNECT"]
}

resource "postgresql_schema" "this" {
  for_each     = local.schemas
  name         = each.value.schema
  database     = postgresql_database.this[each.value.database].name
  owner        = postgresql_role.group["${each.value.database}_owner"].name
  drop_cascade = false
}

resource "postgresql_extension" "this" {
  for_each = local.extensions
  name     = each.value.extension
  database = postgresql_database.this[each.value.database].name
}

resource "postgresql_grant" "schema_usage" {
  for_each    = local.schema_tier
  database    = each.value.database
  schema      = each.value.schema
  role        = each.value.role
  object_type = "schema"
  privileges  = ["USAGE"]

  depends_on = [postgresql_schema.this]
}

resource "postgresql_grant" "tables" {
  for_each    = local.schema_tier
  database    = each.value.database
  schema      = each.value.schema
  role        = each.value.role
  object_type = "table"
  objects     = [] # all existing tables
  privileges  = local.table_privs[each.value.tier]

  depends_on = [postgresql_schema.this]
}

resource "postgresql_default_privileges" "tables" {
  for_each    = local.schema_tier
  database    = each.value.database
  schema      = each.value.schema
  owner       = "${each.value.database}_owner" # migrations MUST `SET ROLE <db>_owner`
  role        = each.value.role
  object_type = "table"
  privileges  = local.table_privs[each.value.tier]
}

resource "postgresql_default_privileges" "sequences" {
  for_each    = local.schema_tier
  database    = each.value.database
  schema      = each.value.schema
  owner       = "${each.value.database}_owner"
  role        = each.value.role
  object_type = "sequence"
  privileges  = local.sequence_privs[each.value.tier]
}

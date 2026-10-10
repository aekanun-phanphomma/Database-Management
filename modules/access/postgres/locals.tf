locals {
  # "<db>:<principal>" => { database, name, [object_id|client_name], type, grant_tier }
  # grant_tier is the "<db>_<tier>" group role name from modules/databases/postgres.
  principals = merge([
    for db, cfg in var.databases : merge(
      {
        for a in try(cfg.access.apps, []) :
        "${db}:${a.principal}" => {
          database = db
          name     = a.principal
          object_id = try(a.object_id, null)
          type     = "service"
          grant    = "${db}_${a.role}"
        }
      },
      {
        "${db}:${cfg.access.migration.principal}" = {
          database  = db
          name      = cfg.access.migration.principal
          object_id = try(cfg.access.migration.object_id, null)
          type      = "service"
          grant     = "${db}_owner"
        }
      },
      {
        for e in try(cfg.access.engineers, []) :
        "${db}:${e.group}" => {
          database  = db
          name      = e.group
          object_id = try(e.object_id, null)
          type      = "group"
          grant     = "${db}_${e.role}"
        }
      }
    )
  ]...)

  # Dedupe by principal name for the Azure bootstrap step (one Entra login
  # role can be granted on multiple databases but is only created once).
  unique_principals = { for name, list in { for k, p in local.principals : p.name => p... } : name => list[0] }
}

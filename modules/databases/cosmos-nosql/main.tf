resource "azurerm_cosmosdb_sql_database" "this" {
  for_each            = var.databases
  name                = each.key
  resource_group_name = var.resource_group_name
  account_name         = var.account_name

  dynamic "autoscale_settings" {
    for_each = each.value.tier == "tier1" ? [] : [1] # tier1 prefers dedicated per-container throughput, not shared DB-level
    content {
      max_throughput = var.shared_throughput_rus * 10
    }
  }

  lifecycle {
    prevent_destroy = true
  }
}

locals {
  # "<db>.<container>" => { database, name, partition_key_path, dedicated_throughput_rus }
  containers = merge([
    for db, cfg in var.databases : {
      for c, ccfg in cfg.containers : "${db}.${c}" => merge(ccfg, { database = db, name = c })
    }
  ]...)
}

resource "azurerm_cosmosdb_sql_container" "this" {
  for_each            = local.containers
  name                 = each.value.name
  resource_group_name  = var.resource_group_name
  account_name          = var.account_name
  database_name         = azurerm_cosmosdb_sql_database.this[each.value.database].name
  partition_key_paths  = [each.value.partition_key_path]

  dynamic "autoscale_settings" {
    for_each = each.value.dedicated_throughput_rus != null ? [each.value.dedicated_throughput_rus] : []
    content {
      max_throughput = autoscale_settings.value
    }
  }

  lifecycle {
    prevent_destroy = true
  }
}

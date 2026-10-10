# Cosmos restores to a brand-new account (spec section 13.3: "restore DB/
# containers into new account, then copy") — there is no in-place restore
# for Cosmos. Only possible when the source account's backup { type =
# "Continuous" } is enabled (modules/azure/nosql/cosmos-nosql sets this).
# TODO(verify): confirm azurerm_cosmosdb_account's `restore` block
# argument names (database_name/collection_names shape especially) for
# the pinned azurerm ~> 4.0 version.
resource "azurerm_cosmosdb_account" "restored" {
  name                = "${var.source_account_name}-r${var.restore_tag}"
  resource_group_name = var.resource_group_name
  location             = var.location
  offer_type            = "Standard"
  kind                  = "GlobalDocumentDB"

  consistency_policy {
    consistency_level = "Session"
  }

  geo_location {
    location          = var.location
    failover_priority = 0
  }

  create_mode = "Restore"

  restore {
    source_cosmosdb_account_id = var.source_account_id
    restore_timestamp_in_utc    = var.restore_time_utc

    dynamic "database" {
      for_each = var.databases_to_restore
      content {
        name = database.value
      }
    }
  }

  backup {
    type = "Continuous"
    tier = "Continuous30Days"
  }

  tags = merge(var.tags, {
    purpose          = "restore"
    "restore-ticket" = var.ticket
    "requested-by"   = var.requested_by
    ttl              = var.ttl_at_utc
  })
}

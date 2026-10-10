# Cosmos DB for MongoDB (RU-based API). For the vCore-based MongoDB
# option, use a different resource entirely (azurerm_mongo_cluster, a
# separate Azure service family) — not covered by this module.
# TODO(verify): confirm whether local_authentication_disabled is
# supported on the Mongo API kind of azurerm_cosmosdb_account for the
# pinned azurerm ~> 4.0 version; Mongo API has historically lagged the
# SQL API on Entra-only auth support, which would make this an ADR 0003
# exception needing a connection-string secret instead.
resource "azurerm_cosmosdb_account" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location             = var.location
  offer_type            = "Standard"
  kind                  = "MongoDB"

  public_network_access_enabled = false
  minimal_tls_version              = "Tls12"

  capabilities {
    name = "EnableMongo"
  }

  consistency_policy {
    consistency_level = "Session"
  }

  geo_location {
    location          = var.location
    failover_priority = 0
  }

  backup {
    type = "Continuous"
    tier = "Continuous30Days"
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [var.cmk_identity_id]
  }

  default_identity_type = "UserAssignedIdentity=${var.cmk_identity_id}"
  key_vault_key_id        = var.cmk_versionless_key_id

  tags = merge(var.tags, { "backup-tier" = var.tier })

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_private_endpoint" "this" {
  name                = "pe-${var.name}"
  resource_group_name = var.resource_group_name
  location             = var.location
  subnet_id            = var.private_endpoint_subnet_id

  private_service_connection {
    name                           = "psc-${var.name}"
    private_connection_resource_id = azurerm_cosmosdb_account.this.id
    subresource_names              = ["MongoDB"]
    is_manual_connection            = false
  }

  private_dns_zone_group {
    name                 = "cosmos-mongo-dns"
    private_dns_zone_ids = [var.private_dns_zone_id]
  }

  tags = var.tags
}

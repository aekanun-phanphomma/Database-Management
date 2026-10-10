# TODO(verify): azurerm_data_protection_backup_vault argument names and the
# immutability block shape against the pinned azurerm ~> 4.0 docs — this
# resource has gained attributes across recent azurerm releases.
resource "azurerm_data_protection_backup_vault" "this" {
  name                = "bvault-${var.name_prefix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  datastore_type      = "VaultStore"
  redundancy          = "GeoRedundant"

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

resource "azurerm_data_protection_backup_vault_customer_managed_key" "this" {
  count                               = 0 # TODO(verify): enable once CMK-on-backup-vault argument set is confirmed for azurerm ~> 4.0
  data_protection_backup_vault_id     = azurerm_data_protection_backup_vault.this.id
  key_vault_key_id                    = null
}

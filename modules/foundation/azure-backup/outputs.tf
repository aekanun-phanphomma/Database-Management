output "vault_id" {
  value = azurerm_data_protection_backup_vault.this.id
}

output "vault_identity_principal_id" {
  value = azurerm_data_protection_backup_vault.this.identity[0].principal_id
}

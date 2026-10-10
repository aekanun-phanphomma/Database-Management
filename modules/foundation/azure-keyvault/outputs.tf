output "key_vault_id" {
  value = azurerm_key_vault.this.id
}

output "key_vault_uri" {
  value = azurerm_key_vault.this.vault_uri
}

output "key_versionless_ids" {
  value = { for k, v in azurerm_key_vault_key.this : k => v.versionless_id }
}

output "key_ids" {
  value = { for k, v in azurerm_key_vault_key.this : k => v.id }
}

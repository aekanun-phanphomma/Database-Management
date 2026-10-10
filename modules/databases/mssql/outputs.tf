output "database_ids" {
  value = { for k, v in azurerm_mssql_database.this : k => v.id }
}

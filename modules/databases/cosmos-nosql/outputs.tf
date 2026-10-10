output "database_names" {
  value = { for k, v in azurerm_cosmosdb_sql_database.this : k => v.name }
}

output "container_ids" {
  value = { for k, v in azurerm_cosmosdb_sql_container.this : k => v.id }
}

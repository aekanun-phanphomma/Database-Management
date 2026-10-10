output "server_id" {
  value = azurerm_mssql_server.this.id
}

output "fqdn" {
  value = azurerm_mssql_server.this.fully_qualified_domain_name
}

output "name" {
  value = azurerm_mssql_server.this.name
}

output "elastic_pool_id" {
  value = var.elastic_pool != null ? azurerm_mssql_elasticpool.this[0].id : null
}

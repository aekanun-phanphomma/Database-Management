output "fqdn" {
  value = azurerm_postgresql_flexible_server.restored.fqdn
}

output "name" {
  value = azurerm_postgresql_flexible_server.restored.name
}

output "ttl_at_utc" {
  value = var.ttl_at_utc
}

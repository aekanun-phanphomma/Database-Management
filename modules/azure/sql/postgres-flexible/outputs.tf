output "fqdn" {
  value = azurerm_postgresql_flexible_server.this.fqdn
}

output "id" {
  value = azurerm_postgresql_flexible_server.this.id
}

output "name" {
  value = azurerm_postgresql_flexible_server.this.name
}

output "max_connections" {
  description = "Server-tier-dependent; read live via SQL at L3 bootstrap rather than hardcoded here."
  value       = null
}

output "allowed_classifications" {
  value = var.allowed_classifications
}

output "max_databases_per_server" {
  value = var.max_databases_per_server
}

output "reserved_connections" {
  value = var.reserved_connections
}

output "name" {
  value = local.name
}

output "endpoint" {
  value = aws_db_instance.this.endpoint
}

output "address" {
  value = aws_db_instance.this.address
}

output "cname_fqdn" {
  value = aws_route53_record.cname.fqdn
}

output "dbi_resource_id" {
  value = aws_db_instance.this.resource_id
}

output "master_user_secret_arn" {
  value = aws_db_instance.this.master_user_secret[0].secret_arn
}

output "max_connections" {
  description = "Falls back to the engine default heuristic reference; real value only known once the instance is running (see L3 bootstrap, which reads it live via SQL if needed)."
  value       = coalesce(var.max_connections_override, 0)
}

output "reserved_connections" {
  value = var.reserved_connections
}

output "allowed_classifications" {
  value = var.allowed_classifications
}

output "max_databases_per_server" {
  value = var.max_databases_per_server
}

output "security_group_id" {
  value = aws_security_group.this.id
}

output "region" {
  value = data.aws_region.current.name
}

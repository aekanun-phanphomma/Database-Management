output "writer_endpoint" {
  value = aws_rds_cluster.this.endpoint
}

output "reader_endpoint" {
  value = aws_rds_cluster.this.reader_endpoint
}

output "cname_fqdn" {
  value = aws_route53_record.cname.fqdn
}

output "master_user_secret_arn" {
  value = aws_rds_cluster.this.master_user_secret[0].secret_arn
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

output "security_group_id" {
  value = aws_security_group.this.id
}

output "restored_endpoint" {
  value = var.source_is_cluster ? aws_rds_cluster.restored[0].endpoint : aws_db_instance.restored[0].endpoint
}

output "restored_identifier" {
  value = var.source_is_cluster ? aws_rds_cluster.restored[0].cluster_identifier : aws_db_instance.restored[0].identifier
}

output "ttl_at_utc" {
  value = var.ttl_at_utc
}

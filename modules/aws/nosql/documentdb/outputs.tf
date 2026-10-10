output "endpoint" {
  value = aws_docdb_cluster.this.endpoint
}

output "master_user_secret_arn" {
  value = aws_docdb_cluster.this.master_user_secret[0].secret_arn
}

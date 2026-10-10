output "endpoint" {
  value = aws_db_instance.this.endpoint
}

output "cname_fqdn" {
  value = aws_route53_record.cname.fqdn
}

output "master_user_secret_arn" {
  value = aws_db_instance.this.master_user_secret[0].secret_arn
}

output "allowed_classifications" {
  value = var.allowed_classifications
}

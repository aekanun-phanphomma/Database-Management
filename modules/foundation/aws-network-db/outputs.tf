output "db_subnet_group_name" {
  value = aws_db_subnet_group.this.name
}

output "private_subnet_ids" {
  value = [for s in aws_subnet.db : s.id]
}

output "baseline_security_group_id" {
  value = aws_security_group.db_baseline.id
}

output "private_dns_zone_id" {
  value = aws_route53_zone.private.zone_id
}

output "private_dns_zone_name" {
  value = aws_route53_zone.private.name
}

output "vpc_id" {
  value = var.vpc_id
}

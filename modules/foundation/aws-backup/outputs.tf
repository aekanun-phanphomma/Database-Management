output "vault_name" {
  value = aws_backup_vault.this.name
}

output "vault_arn" {
  value = aws_backup_vault.this.arn
}

output "backup_role_arn" {
  value = aws_iam_role.backup.arn
}

output "plan_ids" {
  value = { for k, v in aws_backup_plan.this : k => v.id }
}

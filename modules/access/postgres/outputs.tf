output "principal_count" {
  value = length(local.unique_principals)
}

output "aws_db_connect_policy_arns" {
  value = var.cloud == "aws" ? { for k, v in aws_iam_policy.db_connect : k => v.arn } : {}
}

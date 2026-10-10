output "policy_arns" {
  value = { for k, v in aws_iam_policy.table_access : k => v.arn }
}

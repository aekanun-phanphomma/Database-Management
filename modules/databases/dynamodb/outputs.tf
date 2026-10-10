output "table_arns" {
  value = { for k, v in module.table : k => v.table_arn }
}

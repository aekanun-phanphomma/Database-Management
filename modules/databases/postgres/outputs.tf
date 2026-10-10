output "database_names" {
  value = { for k, v in postgresql_database.this : k => v.name }
}

output "group_role_names" {
  value = { for k, v in postgresql_role.group : k => v.name }
}

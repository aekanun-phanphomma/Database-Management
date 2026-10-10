output "database_names" {
  value = { for k, v in mysql_database.this : k => v.name }
}

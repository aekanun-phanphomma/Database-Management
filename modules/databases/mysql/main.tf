resource "mysql_database" "this" {
  for_each               = var.databases
  name                   = each.key
  default_character_set  = each.value.charset
  default_collation      = each.value.collation

  depends_on = [terraform_data.guardrails]

  lifecycle {
    prevent_destroy = true
  }
}

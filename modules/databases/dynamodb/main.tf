module "table" {
  source = "../../aws/nosql/dynamodb-table"

  for_each = var.tables

  name                     = each.key
  hash_key                 = each.value.hash_key
  range_key                = each.value.range_key
  attributes               = each.value.attributes
  global_secondary_indexes = each.value.global_secondary_indexes
  kms_key_arn               = var.kms_key_arn
  tier                       = each.value.tier
  tags                       = var.tags
}

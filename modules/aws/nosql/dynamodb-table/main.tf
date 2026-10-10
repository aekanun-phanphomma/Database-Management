# One table per workload (spec section 10.2 — no "server" boundary to
# share for DynamoDB, so isolation is one table + one IAM policy per
# workload, handled at L3 in modules/access/dynamodb).
resource "aws_dynamodb_table" "this" {
  name         = var.name
  billing_mode = var.billing_mode
  hash_key     = var.hash_key
  range_key    = var.range_key

  dynamic "attribute" {
    for_each = var.attributes
    content {
      name = attribute.key
      type = attribute.value
    }
  }

  dynamic "global_secondary_index" {
    for_each = { for gsi in var.global_secondary_indexes : gsi.name => gsi }
    content {
      name            = global_secondary_index.value.name
      hash_key        = global_secondary_index.value.hash_key
      range_key       = global_secondary_index.value.range_key
      projection_type = global_secondary_index.value.projection_type
    }
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = var.kms_key_arn
  }

  point_in_time_recovery {
    enabled = true
  }

  deletion_protection_enabled = true

  tags = merge(var.tags, { "backup-tier" = var.tier })

  lifecycle {
    prevent_destroy = true
  }
}

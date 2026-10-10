# DynamoDB restore is table-level and always to a NEW table name (spec
# section 13.3) — aws_dynamodb_table has no "restore in place" option
# either, so this matches the platform's restore principle for free.
resource "aws_dynamodb_table" "restored" {
  name     = "${var.source_table_name}-r${var.restore_tag}"
  hash_key = "placeholder" # TODO(verify): restore_source_table_arn-based restores inherit key schema from source; confirm whether hash_key/attribute blocks are still required inputs or ignored when restoring

  attribute {
    name = "placeholder"
    type = "S"
  }

  restore_source_name   = var.restore_time_utc == null ? var.source_table_name : null
  restore_to_latest_time = var.restore_time_utc == null

  # TODO(verify): point-in-time restore to a SPECIFIC time (not latest)
  # uses a different resource shape — confirm aws_dynamodb_table's
  # restore_date_time argument name/availability for hashicorp/aws ~> 6.0.

  server_side_encryption {
    enabled     = true
    kms_key_arn = var.kms_key_arn
  }

  deletion_protection_enabled = false # restored resources are explicitly temporary until cutover

  tags = merge(var.tags, {
    purpose          = "restore"
    "restore-ticket" = var.ticket
    "requested-by"   = var.requested_by
    ttl              = var.ttl_at_utc
  })
}

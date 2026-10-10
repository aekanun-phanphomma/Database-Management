# DynamoDB restore is table-level and always to a NEW table name (spec
# section 13.3/13.5) — aws_dynamodb_table has no "restore in place"
# option either, so this matches the platform's restore principle for
# free. Unlike RDS, the provider does NOT inherit the source table's key
# schema automatically: hash_key/range_key/attributes/GSIs must be
# passed in matching the source exactly (the caller reads them from the
# original aws_dynamodb_table.this resource's own definition).
resource "aws_dynamodb_table" "restored" {
  name         = "${var.source_table_name}-r${var.restore_tag}"
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

  # TODO(verify): the editor's cached schema flags global_secondary_index's
  # hash_key/range_key as deprecated for some provider version — confirm
  # the current non-deprecated attribute names against the pinned
  # hashicorp/aws ~> 6.0 docs (this mirrors modules/aws/nosql/dynamodb-table,
  # which uses the same shape and should be fixed together).
  dynamic "global_secondary_index" {
    for_each = { for gsi in var.global_secondary_indexes : gsi.name => gsi }
    content {
      name            = global_secondary_index.value.name
      hash_key        = global_secondary_index.value.hash_key
      range_key       = global_secondary_index.value.range_key
      projection_type = global_secondary_index.value.projection_type
    }
  }

  restore_source_name = var.restore_time_utc == null ? var.source_table_name : null

  # TODO(verify): confirm aws_dynamodb_table's argument name for restoring
  # to a SPECIFIC point in time (not latest) for hashicorp/aws ~> 6.0 —
  # candidates seen across provider history are `restore_date_time` (used
  # together with `restore_source_name`) vs `restore_source_table_arn` +
  # `restore_to_latest_time`. Wire whichever is correct for the pinned
  # version instead of guessing.
  restore_date_time      = var.restore_time_utc
  restore_to_latest_time = var.restore_time_utc == null

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

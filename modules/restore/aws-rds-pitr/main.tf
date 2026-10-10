# Restore principles (spec section 13.2): always restore to a NEW resource,
# never in place. The restored resource inherits encryption/network/
# classification/tags from the source plus purpose/ticket/ttl markers, and
# stays DBA-only (no L3 access stack applied against it) until validated.
# A nightly cleanup-ttl workflow destroys anything past its ttl.

locals {
  restored_tags = merge(var.tags, {
    purpose          = "restore"
    "restore-ticket" = var.ticket
    "requested-by"   = var.requested_by
    ttl              = var.ttl_at_utc
  })
}

resource "aws_db_instance" "restored" {
  count = var.source_is_cluster ? 0 : 1

  identifier     = "${var.source_identifier}-r${var.restore_tag}"
  instance_class = var.instance_class

  # TODO(verify): confirm whether restore_to_point_in_time wants
  # source_db_instance_identifier (non-cluster) vs source_dbi_resource_id
  # for the pinned hashicorp/aws ~> 6.0 version — both exist historically
  # and the preferred one has shifted across provider releases.
  restore_to_point_in_time {
    source_db_instance_identifier = var.source_identifier
    restore_time                  = var.restore_time_utc
    use_latest_restorable_time    = var.restore_time_utc == null
  }

  db_subnet_group_name   = var.db_subnet_group_name
  vpc_security_group_ids = var.restore_security_group_ids
  kms_key_id              = var.kms_key_arn
  publicly_accessible     = false
  deletion_protection     = false # restored resources are explicitly temporary until cutover
  skip_final_snapshot     = true
  auto_minor_version_upgrade = true

  tags = local.restored_tags
}

resource "aws_rds_cluster" "restored" {
  count = var.source_is_cluster ? 1 : 0

  cluster_identifier = "${var.source_identifier}-r${var.restore_tag}"
  engine             = "aurora-postgresql"

  restore_to_point_in_time {
    source_cluster_identifier  = var.source_identifier
    restore_to_time            = var.restore_time_utc
    use_latest_restorable_time = var.restore_time_utc == null
  }

  db_subnet_group_name   = var.db_subnet_group_name
  vpc_security_group_ids = var.restore_security_group_ids
  kms_key_id              = var.kms_key_arn
  deletion_protection     = false
  skip_final_snapshot     = true

  tags = local.restored_tags
}

resource "aws_rds_cluster_instance" "restored" {
  count              = var.source_is_cluster ? 1 : 0
  identifier         = "${var.source_identifier}-r${var.restore_tag}-0"
  cluster_identifier = aws_rds_cluster.restored[0].id
  engine             = aws_rds_cluster.restored[0].engine
  instance_class     = var.instance_class
  db_subnet_group_name = var.db_subnet_group_name

  tags = local.restored_tags
}

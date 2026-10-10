# DocumentDB has no IAM-DB-auth equivalent (ADR 0003 exception, same
# category as RDS SQL Server). Password handling here assumes the AWS
# provider's `manage_master_user_password` is supported on
# aws_docdb_cluster for the pinned version (mirrors RDS); if it is not,
# fall back to ADR 0003 option 4 (ephemeral random_password + write-only
# argument) instead of a plain `master_password` in state.
# TODO(verify): confirm manage_master_user_password support on
# aws_docdb_cluster for hashicorp/aws ~> 6.0.

resource "aws_security_group" "this" {
  name_prefix = "${var.name}-"
  description = "Dedicated SG for DocumentDB cluster ${var.name}."
  vpc_id      = var.vpc_id

  ingress {
    description     = "DocumentDB from app/runner SGs"
    from_port       = 27017
    to_port         = 27017
    protocol        = "tcp"
    security_groups = var.ingress_security_group_ids
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_docdb_cluster_parameter_group" "this" {
  name   = "${var.name}-params"
  family = "docdb5.0"

  parameter {
    name  = "tls"
    value = "enabled"
  }
  parameter {
    name  = "audit_logs"
    value = "enabled"
  }

  tags = var.tags
}

resource "aws_docdb_cluster" "this" {
  cluster_identifier              = var.name
  engine                          = "docdb"
  engine_version                  = var.engine_version
  master_username                 = "dbmaster"
  manage_master_user_password     = true
  master_user_secret_kms_key_id   = var.secrets_kms_key_arn
  db_subnet_group_name             = var.db_subnet_group_name
  vpc_security_group_ids           = [aws_security_group.this.id]
  storage_encrypted                = true
  kms_key_id                       = var.kms_key_arn
  db_cluster_parameter_group_name = aws_docdb_cluster_parameter_group.this.name
  backup_retention_period          = var.backup_policy.pitr_retention_days
  preferred_backup_window           = "17:00-18:00"
  preferred_maintenance_window       = "sun:18:30-sun:19:30"
  deletion_protection               = true
  skip_final_snapshot               = false
  final_snapshot_identifier         = "${var.name}-final"
  enabled_cloudwatch_logs_exports   = ["audit", "profiler"]

  tags = merge(var.tags, { "backup-tier" = var.tier })

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_docdb_cluster_instance" "this" {
  count              = var.instance_count
  identifier         = "${var.name}-${count.index}"
  cluster_identifier = aws_docdb_cluster.this.id
  instance_class     = var.instance_class

  tags = var.tags
}

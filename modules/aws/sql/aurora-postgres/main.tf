resource "aws_security_group" "this" {
  name_prefix = "${var.name}-"
  description = "Dedicated SG for Aurora cluster ${var.name}."
  vpc_id      = var.vpc_id

  ingress {
    description     = "Postgres from app/runner SGs"
    from_port       = 5432
    to_port         = 5432
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

resource "aws_rds_cluster_parameter_group" "this" {
  name   = "${var.name}-pg16"
  family = "aurora-postgresql16" # TODO(verify): derive from engine_version major, confirm family name for pinned version

  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }
  parameter {
    name         = "shared_preload_libraries"
    value        = "pg_stat_statements,pgaudit"
    apply_method = "pending-reboot"
  }
  parameter {
    name  = "pgaudit.log"
    value = "ddl,role"
  }

  dynamic "parameter" {
    for_each = var.max_connections_override != null ? [var.max_connections_override] : []
    content {
      name         = "max_connections"
      value        = tostring(parameter.value)
      apply_method = "pending-reboot"
    }
  }

  tags = var.tags
}

resource "aws_rds_cluster" "this" {
  cluster_identifier                  = var.name
  engine                              = "aurora-postgresql"
  engine_version                      = var.engine_version
  database_name                       = "postgres"
  master_username                     = "dbmaster"
  manage_master_user_password         = true
  master_user_secret_kms_key_id       = var.secrets_kms_key_arn
  db_subnet_group_name                = var.db_subnet_group_name
  vpc_security_group_ids              = [aws_security_group.this.id]
  storage_encrypted                   = true
  kms_key_id                          = var.kms_key_arn
  iam_database_authentication_enabled = true
  db_cluster_parameter_group_name     = aws_rds_cluster_parameter_group.this.name
  backup_retention_period             = var.backup_policy.pitr_retention_days
  preferred_backup_window             = "17:00-18:00"
  preferred_maintenance_window        = "sun:18:30-sun:19:30"
  copy_tags_to_snapshot                = true
  deletion_protection                  = true
  skip_final_snapshot                  = false
  final_snapshot_identifier            = "${var.name}-final"
  enabled_cloudwatch_logs_exports       = ["postgresql"]

  tags = merge(var.tags, { "backup-tier" = var.tier })

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_rds_cluster_instance" "this" {
  count              = var.instance_count
  identifier         = "${var.name}-${count.index}"
  cluster_identifier = aws_rds_cluster.this.id
  engine             = aws_rds_cluster.this.engine
  engine_version     = aws_rds_cluster.this.engine_version
  instance_class     = var.instance_class
  db_subnet_group_name = var.db_subnet_group_name
  performance_insights_enabled     = true
  performance_insights_kms_key_id  = var.kms_key_arn
  monitoring_interval              = 30
  auto_minor_version_upgrade       = true

  tags = var.tags
}

resource "aws_db_event_subscription" "this" {
  name             = "${var.name}-events"
  sns_topic        = var.alarm_topic_arn
  source_type      = "db-cluster"
  source_ids       = [aws_rds_cluster.this.id]
  event_categories = ["failover", "failure", "notification"]

  tags = var.tags
}

resource "aws_route53_record" "cname" {
  zone_id = var.private_dns_zone_id
  name    = "${var.name}.${var.private_dns_zone_name}"
  type    = "CNAME"
  ttl     = 60
  records = [aws_rds_cluster.this.endpoint]
}

resource "aws_route53_record" "cname_reader" {
  zone_id = var.private_dns_zone_id
  name    = "${var.name}-ro.${var.private_dns_zone_name}"
  type    = "CNAME"
  ttl     = 60
  records = [aws_rds_cluster.this.reader_endpoint]
}

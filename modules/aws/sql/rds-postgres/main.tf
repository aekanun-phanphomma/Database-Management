data "aws_region" "current" {}

resource "aws_security_group" "this" {
  name_prefix = "${var.name}-"
  description = "Dedicated SG for RDS instance ${var.name} (spec 8.1 — one SG per server)."
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

resource "aws_db_parameter_group" "this" {
  name   = "${var.name}-pg16"
  family = "postgres16" # TODO(verify): derive from var.engine_version major instead of hardcoding, once engine_version is finalized

  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }
  parameter {
    name  = "ssl_min_protocol_version"
    value = "TLSv1.2"
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
  parameter {
    name  = "log_connections"
    value = "1"
  }
  parameter {
    name  = "log_disconnections"
    value = "1"
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

resource "aws_db_event_subscription" "this" {
  name      = "${var.name}-events"
  sns_topic = var.alarm_topic_arn
  source_type = "db-instance"
  source_ids  = [aws_db_instance.this.id]
  event_categories = ["availability", "deletion", "failover", "failure", "maintenance", "notification", "recovery"]

  tags = var.tags
}

resource "aws_db_instance" "this" {
  identifier                          = var.name
  engine                              = "postgres"
  engine_version                      = var.engine_version
  instance_class                      = var.instance_class
  allocated_storage                   = var.allocated_storage
  max_allocated_storage               = var.max_allocated_storage
  storage_type                        = "gp3"
  storage_encrypted                   = true
  kms_key_id                          = var.kms_key_arn
  manage_master_user_password         = true
  master_user_secret_kms_key_id       = var.secrets_kms_key_arn
  username                            = "dbmaster"
  iam_database_authentication_enabled = true
  db_subnet_group_name                = var.db_subnet_group_name
  vpc_security_group_ids              = [aws_security_group.this.id]
  publicly_accessible                 = false
  multi_az                            = var.tier == "tier1"
  parameter_group_name                = aws_db_parameter_group.this.name
  ca_cert_identifier                  = "rds-ca-rsa2048-g1"
  backup_retention_period             = var.backup_policy.pitr_retention_days
  backup_window                       = "17:00-18:00"
  maintenance_window                  = "sun:18:30-sun:19:30"
  copy_tags_to_snapshot               = true
  delete_automated_backups            = false
  deletion_protection                 = true
  skip_final_snapshot                 = false
  final_snapshot_identifier           = "${var.name}-final"
  performance_insights_enabled        = true
  performance_insights_kms_key_id     = var.kms_key_arn
  monitoring_interval                 = 30
  monitoring_role_arn                 = var.enhanced_monitoring_role_arn
  enabled_cloudwatch_logs_exports     = ["postgresql", "upgrade", "iam-db-auth-error"]
  auto_minor_version_upgrade          = true
  tags = merge(var.tags, {
    "backup-tier" = var.tier
  })

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_route53_record" "cname" {
  zone_id = var.private_dns_zone_id
  name    = "${var.name}.${var.private_dns_zone_name}"
  type    = "CNAME"
  ttl     = 60
  records = [aws_db_instance.this.address]
}

# Guardrails are evaluated by the caller (L2) against this server's outputs,
# per spec section 10.3 — this module only exposes the numbers to check.

resource "aws_security_group" "this" {
  name_prefix = "${var.name}-"
  description = "Dedicated SG for RDS MySQL instance ${var.name}."
  vpc_id      = var.vpc_id

  ingress {
    description     = "MySQL from app/runner SGs"
    from_port       = 3306
    to_port         = 3306
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
  name   = "${var.name}-mysql8"
  family = "mysql8.0" # TODO(verify): confirm family string for pinned engine_version

  parameter {
    name  = "require_secure_transport"
    value = "ON"
  }
  parameter {
    name         = "general_log"
    value        = "1"
    apply_method = "immediate"
  }

  tags = var.tags
}

resource "aws_db_instance" "this" {
  identifier                          = var.name
  engine                              = "mysql"
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
  backup_retention_period             = var.backup_policy.pitr_retention_days
  backup_window                       = "17:00-18:00"
  maintenance_window                  = "sun:18:30-sun:19:30"
  copy_tags_to_snapshot               = true
  deletion_protection                 = true
  skip_final_snapshot                 = false
  final_snapshot_identifier           = "${var.name}-final"
  performance_insights_enabled        = true
  performance_insights_kms_key_id     = var.kms_key_arn
  enabled_cloudwatch_logs_exports     = ["audit", "error", "general", "slowquery"]
  auto_minor_version_upgrade          = true

  tags = merge(var.tags, { "backup-tier" = var.tier })

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

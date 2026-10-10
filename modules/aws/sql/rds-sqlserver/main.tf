# RDS SQL Server has no IAM-DB-auth equivalent to rds_iam (that's
# Postgres/MySQL only). The passwordless-first path here is Windows/
# Kerberos auth via AWS Managed Microsoft AD (`domain` / `domain_iam_role_name`
# below) — documented as an explicit exception to ADR 0003's default order.
# TODO(verify): confirm domain/domain_iam_role_name argument availability
# and the AWS Managed AD directory setup this depends on before relying on
# it; var.directory_id defaults to null, which skips domain-join entirely
# and falls back to SQL auth (option 2 of ADR 0003 — engine-managed secret).

resource "aws_security_group" "this" {
  name_prefix = "${var.name}-"
  description = "Dedicated SG for RDS SQL Server instance ${var.name}."
  vpc_id      = var.vpc_id

  ingress {
    description     = "SQL Server from app/runner SGs"
    from_port       = 1433
    to_port         = 1433
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

# Empty by default — no options enabled. Add `option {}` blocks here for
# whatever the actual workload needs (e.g. SSIS, TDE); left empty rather
# than guessing at a placeholder option name.
resource "aws_db_option_group" "this" {
  name                 = "${var.name}-opts"
  engine_name          = var.engine
  major_engine_version = split(".", var.engine_version)[0]

  tags = var.tags
}

resource "aws_db_instance" "this" {
  identifier                     = var.name
  engine                         = var.engine
  engine_version                 = var.engine_version
  instance_class                 = var.instance_class
  allocated_storage               = var.allocated_storage
  storage_type                   = "gp3"
  storage_encrypted              = true
  kms_key_id                     = var.kms_key_arn
  manage_master_user_password    = true
  master_user_secret_kms_key_id  = var.secrets_kms_key_arn
  username                       = "dbmaster"
  db_subnet_group_name            = var.db_subnet_group_name
  vpc_security_group_ids          = [aws_security_group.this.id]
  option_group_name               = aws_db_option_group.this.name
  publicly_accessible              = false
  multi_az                         = var.tier == "tier1"
  backup_retention_period          = var.backup_policy.pitr_retention_days
  backup_window                    = "17:00-18:00"
  maintenance_window               = "sun:18:30-sun:19:30"
  copy_tags_to_snapshot            = true
  deletion_protection              = true
  skip_final_snapshot              = false
  final_snapshot_identifier        = "${var.name}-final"
  enabled_cloudwatch_logs_exports = ["error"]
  auto_minor_version_upgrade       = true

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

# Redis/Valkey has no native identity-based auth, so this is an explicit
# ADR 0003 exception: the AUTH token is rotation-owned (option 3) — read
# ephemerally from Secrets Manager here, never written to Terraform state.
# TODO(verify): confirm aws_elasticache_replication_group's auth_token
# argument accepts a write-only form (`auth_token_wo`) in the pinned
# hashicorp/aws ~> 6.0 provider; if not, this falls back to passing the
# ephemeral value directly, which IS still kept out of state by the
# ephemeral resource but requires re-running apply whenever the token
# rotates (ignore_changes cannot be used on a required argument).
ephemeral "aws_secretsmanager_secret_version" "auth_token" {
  secret_id = var.auth_token_secret_arn
}

resource "aws_security_group" "this" {
  name_prefix = "${var.name}-"
  description = "Dedicated SG for ElastiCache replication group ${var.name}."
  vpc_id      = var.vpc_id

  ingress {
    description     = "Redis/Valkey from app/runner SGs"
    from_port       = 6379
    to_port         = 6379
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

resource "aws_elasticache_replication_group" "this" {
  replication_group_id       = var.name
  description                 = "Managed by db-platform"
  engine                      = var.engine
  engine_version               = var.engine_version
  node_type                    = var.node_type
  num_cache_clusters            = var.num_cache_clusters
  automatic_failover_enabled   = var.num_cache_clusters > 1
  multi_az_enabled              = var.tier == "tier1"
  subnet_group_name             = var.subnet_group_name
  security_group_ids            = [aws_security_group.this.id]
  at_rest_encryption_enabled    = true
  kms_key_id                    = var.kms_key_arn
  transit_encryption_enabled    = true
  auth_token                    = jsondecode(ephemeral.aws_secretsmanager_secret_version.auth_token.secret_string)["auth_token"]
  auto_minor_version_upgrade    = true
  snapshot_retention_limit       = 7

  tags = merge(var.tags, { "backup-tier" = var.tier })

  lifecycle {
    prevent_destroy = true
  }
}

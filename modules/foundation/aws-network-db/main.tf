data "aws_region" "current" {}
data "aws_vpc" "this" {
  id = var.vpc_id
}

# -----------------------------------------------------------------------------
# DB subnets (private, no IGW route) + subnet group
# -----------------------------------------------------------------------------
resource "aws_subnet" "db" {
  for_each = { for idx, az in var.availability_zones : az => var.private_subnet_cidrs[idx] }

  vpc_id            = var.vpc_id
  availability_zone = each.key
  cidr_block        = each.value

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-db-${each.key}"
    tier = "database"
  })
}

resource "aws_route_table_association" "db" {
  for_each = aws_subnet.db

  subnet_id      = each.value.id
  route_table_id = var.private_route_table_ids[index(var.availability_zones, each.key)]
}

resource "aws_db_subnet_group" "this" {
  name       = "${var.name_prefix}-db"
  subnet_ids = [for s in aws_subnet.db : s.id]
  tags       = var.tags
}

# -----------------------------------------------------------------------------
# Security group shared by every server (per-server ingress rules are added
# by the L1 server module; this group just establishes the baseline deny-all
# default and egress restriction — see spec section 8.1, "one SG per server"
# is implemented at L1 using this as a template/reference, not duplicated
# here, since L0 doesn't know engine ports yet).
# -----------------------------------------------------------------------------
resource "aws_security_group" "db_baseline" {
  name_prefix = "${var.name_prefix}-db-baseline-"
  description = "Baseline DB security group: no ingress by default, egress restricted to VPC."
  vpc_id      = var.vpc_id

  egress {
    description = "VPC-internal only"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

# -----------------------------------------------------------------------------
# VPC endpoints
# -----------------------------------------------------------------------------
resource "aws_security_group" "endpoints" {
  name_prefix = "${var.name_prefix}-vpce-"
  description = "Allows runner + app subnets to reach interface VPC endpoints"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTPS from runner subnet(s)"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.runner_cidr_blocks
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

resource "aws_vpc_endpoint" "interface" {
  for_each = toset(var.interface_endpoint_services)

  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.${each.key}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [for s in aws_subnet.db : s.id]
  security_group_ids  = [aws_security_group.endpoints.id]
  private_dns_enabled = true

  tags = merge(var.tags, { Name = "${var.name_prefix}-vpce-${each.key}" })
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = var.private_route_table_ids

  tags = merge(var.tags, { Name = "${var.name_prefix}-vpce-s3" })
}

resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.dynamodb"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = var.private_route_table_ids

  tags = merge(var.tags, { Name = "${var.name_prefix}-vpce-dynamodb" })
}

# -----------------------------------------------------------------------------
# Private DNS — stable per-server CNAME lives at L1; this only creates the zone.
# -----------------------------------------------------------------------------
resource "aws_route53_zone" "private" {
  name = var.private_dns_zone_name

  vpc {
    vpc_id = var.vpc_id
  }

  tags = var.tags
}

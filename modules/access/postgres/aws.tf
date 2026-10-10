# IAM DB auth login roles (spec section 11.3). The bootstrap `tf_admin`
# role and the `postgresql` provider's IAM-auth connection are established
# by the live/ stack (ephemeral read of the RDS-managed master secret,
# used exactly once) — this module only creates the per-principal login
# roles and the IAM policy each principal's AWS role needs to call
# rds-db:connect.
resource "postgresql_role" "aws_login" {
  for_each = var.cloud == "aws" ? local.principals : {}

  name             = each.value.name
  login            = true
  roles            = ["rds_iam", each.value.grant]
  connection_limit = 20
  # Passwordless: rds_iam membership is what authenticates. No password set.
}

data "aws_iam_policy_document" "db_connect" {
  for_each = var.cloud == "aws" ? local.unique_principals : {}

  statement {
    sid       = "RdsDbConnect"
    effect    = "Allow"
    actions   = ["rds-db:connect"]
    resources = ["arn:aws:rds-db:${var.region}:${var.account_id}:dbuser:${var.dbi_resource_id}/${each.value.name}"]
  }
}

resource "aws_iam_policy" "db_connect" {
  for_each = var.cloud == "aws" ? local.unique_principals : {}

  name   = "db-connect-${each.value.name}"
  policy = data.aws_iam_policy_document.db_connect[each.key].json
  tags   = var.tags
}

# The YAML `principal` field is the IAM role name for AWS (spec section
# 9.1). The role itself is owned by the app team's own IaC; we only
# attach the connect policy to it, and refuse to proceed if it doesn't
# exist yet rather than silently skipping the attachment.
data "aws_iam_role" "app" {
  for_each = var.cloud == "aws" ? local.unique_principals : {}
  name     = each.value.name
}

resource "aws_iam_role_policy_attachment" "db_connect" {
  for_each   = var.cloud == "aws" ? local.unique_principals : {}
  role       = data.aws_iam_role.app[each.key].name
  policy_arn = aws_iam_policy.db_connect[each.key].arn
}

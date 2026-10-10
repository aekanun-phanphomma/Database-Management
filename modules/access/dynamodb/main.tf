locals {
  ro_actions = ["dynamodb:GetItem", "dynamodb:BatchGetItem", "dynamodb:Query", "dynamodb:Scan", "dynamodb:DescribeTable"]
  rw_actions = concat(local.ro_actions, [
    "dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:DeleteItem",
    "dynamodb:BatchWriteItem", "dynamodb:ConditionCheckItem",
  ])
}

data "aws_iam_policy_document" "table_access" {
  for_each = var.principals

  statement {
    sid       = "TableAccess"
    effect    = "Allow"
    actions   = each.value.role == "rw" ? local.rw_actions : local.ro_actions
    resources = [var.table_arn, "${var.table_arn}/index/*"]

    dynamic "condition" {
      for_each = length(each.value.leading_keys) > 0 ? [1] : []
      content {
        test     = "ForAllValues:StringEquals"
        variable = "dynamodb:LeadingKeys"
        values   = each.value.leading_keys
      }
    }
  }

  # Key policy grants kms:Decrypt/GenerateDataKey "via service" (see
  # modules/foundation/aws-kms); this statement is what lets a principal
  # actually invoke that grant.
  statement {
    sid       = "TableKeyAccess"
    effect    = "Allow"
    actions   = ["kms:Decrypt", "kms:GenerateDataKey"]
    resources = [var.table_kms_key_arn]
    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["dynamodb.*.amazonaws.com"] # TODO(verify): wildcard region support in kms:ViaService condition values
    }
  }
}

resource "aws_iam_policy" "table_access" {
  for_each = var.principals

  name   = "ddb-${basename(var.table_arn)}-${each.key}"
  policy = data.aws_iam_policy_document.table_access[each.key].json
  tags   = var.tags
}

data "aws_iam_role" "app" {
  for_each = var.principals
  name     = each.key
}

resource "aws_iam_role_policy_attachment" "table_access" {
  for_each   = var.principals
  role       = data.aws_iam_role.app[each.key].name
  policy_arn = aws_iam_policy.table_access[each.key].arn
}

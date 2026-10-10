data "aws_caller_identity" "current" {}

locals {
  account_root = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
}

data "aws_iam_policy_document" "key" {
  for_each = toset(var.purposes)

  # Root account retains ultimate control so IAM can grant/deny usage;
  # actual usage is still scoped by the statements below.
  statement {
    sid     = "EnableRootPermissions"
    effect  = "Allow"
    actions = ["kms:*"]
    principals {
      type        = "AWS"
      identifiers = [local.account_root]
    }
    resources = ["*"]
  }

  statement {
    sid    = "KeyAdministration"
    effect = "Allow"
    actions = [
      "kms:Create*", "kms:Describe*", "kms:Enable*", "kms:List*",
      "kms:Put*", "kms:Update*", "kms:Revoke*", "kms:Disable*",
      "kms:Get*", "kms:TagResource", "kms:UntagResource",
      "kms:EnableKeyRotation", "kms:DisableKeyRotation",
    ]
    principals {
      type        = "AWS"
      identifiers = var.key_admin_arns
    }
    resources = ["*"]
  }

  statement {
    sid    = "KeyUsage"
    effect = "Allow"
    actions = [
      "kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*",
      "kms:GenerateDataKey*", "kms:DescribeKey",
    ]
    principals {
      type        = "AWS"
      identifiers = lookup(var.key_user_arns, each.key, [])
    }
    resources = ["*"]
  }

  statement {
    sid    = "DenyScheduleDeletionExceptBreakGlass"
    effect = "Deny"
    actions = ["kms:ScheduleKeyDeletion", "kms:DeleteAlias"]
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    resources = ["*"]
    condition {
      test     = "StringNotLike"
      variable = "aws:PrincipalArn"
      values   = length(var.break_glass_arns) > 0 ? var.break_glass_arns : ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/__no-break-glass-configured__"]
    }
  }
}

resource "aws_kms_key" "this" {
  for_each = toset(var.purposes)

  description             = "${var.name_prefix} CMK for ${each.key}"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  multi_region            = contains(var.multi_region, each.key)
  policy                  = data.aws_iam_policy_document.key[each.key].json

  tags = merge(var.tags, { purpose = each.key })
}

resource "aws_kms_alias" "this" {
  for_each = aws_kms_key.this

  name          = "alias/${var.name_prefix}-${each.key}"
  target_key_id = each.value.key_id
}

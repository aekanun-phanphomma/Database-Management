resource "aws_backup_vault" "this" {
  name        = "${var.name_prefix}-vault"
  kms_key_arn = var.backup_kms_key_arn
  tags        = var.tags
}

# Compliance-mode Vault Lock. Only enabled on the module instance deployed
# into the isolated backup account — see spec section 3.8 and ADR 0004.
# TODO(verify): confirm aws_backup_vault_lock_configuration argument names
# against the pinned hashicorp/aws ~> 6.0 docs (changeable_for_days vs
# changeable_for_days_days naming has shifted across provider majors).
resource "aws_backup_vault_lock_configuration" "this" {
  count = var.enable_vault_lock ? 1 : 0

  backup_vault_name  = aws_backup_vault.this.name
  min_retention_days = var.vault_lock_min_retention_days
  max_retention_days = var.vault_lock_max_retention_days
  changeable_for_days = var.vault_lock_changeable_for_days
}

data "aws_iam_policy_document" "backup_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["backup.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "backup" {
  name               = "${var.name_prefix}-backup-role"
  assume_role_policy = data.aws_iam_policy_document.backup_assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "backup_service" {
  role       = aws_iam_role.backup.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

resource "aws_iam_role_policy_attachment" "restore_service" {
  role       = aws_iam_role.backup.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForRestores"
}

resource "aws_backup_plan" "this" {
  for_each = var.tiers
  name     = "${var.name_prefix}-${each.key}"

  rule {
    rule_name         = "${each.key}-daily"
    target_vault_name = aws_backup_vault.this.name
    schedule          = "cron(0 17 * * ? *)" # 17:00 UTC daily; aligns with RDS backup_window in L1
    lifecycle {
      delete_after = each.value.pitr_retention_days
    }

    dynamic "copy_action" {
      for_each = each.value.cross_account_locked ? [1] : []
      content {
        destination_vault_arn = var.backup_account_vault_arn
        lifecycle {
          delete_after = max(each.value.pitr_retention_days, each.value.long_term_monthly * 30)
        }
      }
    }
  }

  dynamic "rule" {
    for_each = each.value.long_term_monthly > 0 ? [1] : []
    content {
      rule_name         = "${each.key}-monthly"
      target_vault_name = aws_backup_vault.this.name
      schedule          = "cron(0 18 1 * ? *)"
      lifecycle {
        delete_after = each.value.long_term_monthly * 30
      }

      dynamic "copy_action" {
        for_each = each.value.cross_account_locked ? [1] : []
        content {
          destination_vault_arn = var.backup_account_vault_arn
          lifecycle {
            delete_after = each.value.long_term_monthly * 30
          }
        }
      }
    }
  }

  tags = var.tags
}

resource "aws_backup_selection" "this" {
  for_each = var.tiers

  name         = "${var.name_prefix}-${each.key}-selection"
  plan_id      = aws_backup_plan.this[each.key].id
  iam_role_arn = aws_iam_role.backup.arn

  selection_tag {
    type  = "STRINGEQUALS"
    key   = var.resource_type_tag_key
    value = each.key
  }
}

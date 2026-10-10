# -----------------------------------------------------------------------------
# AWS: S3 bucket with SSE-KMS, versioning, Object Lock (governance mode),
# TLS-only bucket policy. `use_lockfile = true` in the backend config
# (live/root.hcl) replaces the old DynamoDB lock table for S3 native locking
# on Terraform >= 1.11 / AWS provider >= 6.0 — no lock table is created here.
# -----------------------------------------------------------------------------
resource "aws_s3_bucket" "tfstate" {
  count = var.cloud == "aws" ? 1 : 0

  bucket              = "${var.name_prefix}-tfstate"
  object_lock_enabled = true
  tags                = var.tags
}

resource "aws_s3_bucket_versioning" "tfstate" {
  count  = var.cloud == "aws" ? 1 : 0
  bucket = aws_s3_bucket.tfstate[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  count  = var.cloud == "aws" ? 1 : 0
  bucket = aws_s3_bucket.tfstate[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.tfstate_kms_key_arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "tfstate" {
  count  = var.cloud == "aws" ? 1 : 0
  bucket = aws_s3_bucket.tfstate[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_object_lock_configuration" "tfstate" {
  count  = var.cloud == "aws" ? 1 : 0
  bucket = aws_s3_bucket.tfstate[0].id

  rule {
    default_retention {
      mode = "GOVERNANCE"
      days = 90
    }
  }
}

data "aws_iam_policy_document" "tfstate_bucket_policy" {
  count = var.cloud == "aws" ? 1 : 0

  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.tfstate[0].arn, "${aws_s3_bucket.tfstate[0].arn}/*"]
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "tfstate" {
  count  = var.cloud == "aws" ? 1 : 0
  bucket = aws_s3_bucket.tfstate[0].id
  policy = data.aws_iam_policy_document.tfstate_bucket_policy[0].json
}

# -----------------------------------------------------------------------------
# Azure: Storage Account with CMK, private endpoint, AAD-only auth.
# TODO(verify): private endpoint + private DNS zone link against the
# centrally-managed `privatelink.blob.core.windows.net` zone (owned by
# azure-network-db / the connectivity subscription) is wired at the live/
# stack level, not duplicated here.
# -----------------------------------------------------------------------------
resource "azurerm_storage_account" "tfstate" {
  count = var.cloud == "azure" ? 1 : 0

  name                            = replace("st${var.name_prefix}tfstate", "-", "")
  resource_group_name             = var.resource_group_name
  location                        = var.location
  account_tier                    = "Standard"
  account_replication_type        = "ZRS"
  min_tls_version                 = "TLS1_2"
  shared_access_key_enabled       = false
  public_network_access_enabled   = false
  allow_nested_items_to_be_public = false

  identity {
    type         = "UserAssigned"
    identity_ids = [var.tfstate_cmk_identity_id]
  }

  customer_managed_key {
    key_vault_key_id          = var.tfstate_cmk_key_vault_key_id
    user_assigned_identity_id = var.tfstate_cmk_identity_id
  }

  blob_properties {
    versioning_enabled = true
    delete_retention_policy {
      days = 30
    }
    container_delete_retention_policy {
      days = 30
    }
  }

  tags = var.tags
}

resource "azurerm_storage_container" "tfstate" {
  count = var.cloud == "azure" ? 1 : 0
  name  = "tfstate"
  # TODO(verify): azurerm ~> 4.0 — confirm whether this resource takes
  # storage_account_id (newer) or storage_account_name (older azurerm 3.x
  # style); the attribute was renamed across azurerm major versions.
  storage_account_id    = azurerm_storage_account.tfstate[0].id
  container_access_type = "private"
}

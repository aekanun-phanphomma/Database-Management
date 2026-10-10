output "aws_bucket_name" {
  value = var.cloud == "aws" ? aws_s3_bucket.tfstate[0].bucket : null
}

output "azure_storage_account_name" {
  value = var.cloud == "azure" ? azurerm_storage_account.tfstate[0].name : null
}

output "azure_container_name" {
  value = var.cloud == "azure" ? azurerm_storage_container.tfstate[0].name : null
}

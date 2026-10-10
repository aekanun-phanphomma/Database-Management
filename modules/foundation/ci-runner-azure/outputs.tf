output "container_app_job_id" {
  value = azurerm_container_app_job.runner.id
}

output "environment_id" {
  value = azurerm_container_app_environment.runners.id
}

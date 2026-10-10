# Ephemeral Container Apps job runner inside the runner subnet. No static
# credentials: each pipeline layer's Entra app registration gets a GitHub
# OIDC federated credential, so `azure/login@...` in the workflow exchanges
# a GitHub Actions OIDC token for an Azure token directly.

resource "azuread_application_federated_identity_credential" "layer" {
  for_each = var.l_layer_app_registration_ids

  application_id = "/applications/${each.value}" # TODO(verify): azuread ~> 3.0 — confirm application_id expects the object id in this "/applications/<id>" form vs the bare object id
  display_name   = "gh-oidc-${each.key}"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = "repo:${var.github_org}/${var.github_repo}:environment:${each.key}"
}

resource "azurerm_container_app_environment" "runners" {
  name                       = "cae-${var.name_prefix}-runners"
  resource_group_name       = var.resource_group_name
  location                  = var.location
  infrastructure_subnet_id  = var.runner_subnet_id
  internal_load_balancer_enabled = true
  tags                      = var.tags
}

resource "azurerm_container_app_job" "runner" {
  name                         = "caj-${var.name_prefix}-runner"
  resource_group_name          = var.resource_group_name
  location                     = var.location
  container_app_environment_id = azurerm_container_app_environment.runners.id

  replica_timeout_in_seconds = 1800
  replica_retry_limit        = 0

  manual_trigger_config {
    parallelism              = 1
    replica_completion_count = 1
  }

  template {
    container {
      name   = "runner"
      image  = var.runner_image
      cpu    = 1.0
      memory = "2Gi"

      env {
        name  = "GITHUB_ORG"
        value = var.github_org
      }
      env {
        name  = "GITHUB_REPO"
        value = var.github_repo
      }
      env {
        name  = "EPHEMERAL"
        value = "true"
      }
    }
  }

  tags = var.tags
}

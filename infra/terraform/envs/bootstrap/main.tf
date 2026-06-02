resource "azurerm_resource_group" "bootstrap" {
  name     = "rg-boutique-tfstate-weu"
  location = var.location
  tags     = var.tags
}

resource "azurerm_storage_account" "tfstate" {
  name                     = var.storage_account_name
  resource_group_name      = azurerm_resource_group.bootstrap.name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "GRS"
  min_tls_version          = "TLS1_2"
  tags                     = var.tags

  blob_properties {
    delete_retention_policy {
      days = 7
    }
  }
}

resource "azurerm_storage_container" "shared" {
  name                  = "tfstate-shared"
  storage_account_name  = azurerm_storage_account.tfstate.name
  container_access_type = "private"
}

resource "azurerm_storage_container" "dev" {
  name                  = "tfstate-dev"
  storage_account_name  = azurerm_storage_account.tfstate.name
  container_access_type = "private"
}

resource "azurerm_storage_container" "stage" {
  name                  = "tfstate-stage"
  storage_account_name  = azurerm_storage_account.tfstate.name
  container_access_type = "private"
}

resource "azurerm_storage_container" "prod" {
  name                  = "tfstate-prod"
  storage_account_name  = azurerm_storage_account.tfstate.name
  container_access_type = "private"
}

data "azurerm_subscription" "current" {}

locals {
  subscription_budget_enabled = var.enable_subscription_budget && length(var.budget_notification_emails) > 0
}

# Optional Phase 8 cost alert: Azure Consumption budget at subscription scope (80% actual).
resource "azurerm_consumption_budget_subscription" "monthly" {
  count = local.subscription_budget_enabled ? 1 : 0

  name            = var.budget_name
  subscription_id = data.azurerm_subscription.current.id

  amount     = var.budget_monthly_amount
  time_grain = "Monthly"

  time_period {
    start_date = var.budget_period_start
    end_date   = var.budget_period_end
  }

  notification {
    enabled        = true
    threshold      = 80.0
    operator       = "EqualTo"
    threshold_type = "Actual"
    contact_emails = var.budget_notification_emails
  }
}

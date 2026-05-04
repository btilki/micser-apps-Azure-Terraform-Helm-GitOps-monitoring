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
  storage_account_id    = azurerm_storage_account.tfstate.id
  container_access_type = "private"
}

resource "azurerm_storage_container" "dev" {
  name                  = "tfstate-dev"
  storage_account_id    = azurerm_storage_account.tfstate.id
  container_access_type = "private"
}

resource "azurerm_storage_container" "stage" {
  name                  = "tfstate-stage"
  storage_account_id    = azurerm_storage_account.tfstate.id
  container_access_type = "private"
}

resource "azurerm_storage_container" "prod" {
  name                  = "tfstate-prod"
  storage_account_id    = azurerm_storage_account.tfstate.id
  container_access_type = "private"
}

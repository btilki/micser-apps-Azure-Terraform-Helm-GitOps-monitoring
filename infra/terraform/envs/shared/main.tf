locals {
  tags = merge(
    var.tags,
    {
      owner = var.owner_email
    }
  )
}

resource "azurerm_resource_group" "shared" {
  name     = "rg-boutique-shared-weu"
  location = var.location
  tags     = local.tags
}

module "network" {
  source              = "../../modules/network"
  location            = var.location
  tags                = local.tags
  resource_group_name = azurerm_resource_group.shared.name
  vnet_name           = "vnet-boutique-weu"
}

module "log_analytics" {
  source              = "../../modules/log_analytics"
  location            = var.location
  tags                = local.tags
  resource_group_name = azurerm_resource_group.shared.name
  workspace_name      = "log-boutique-weu"
}

module "dns" {
  source              = "../../modules/dns"
  resource_group_name = azurerm_resource_group.shared.name
  tags                = local.tags
  zone_name           = var.dns_zone_name
}

resource "azurerm_public_ip" "ingress" {
  name                = "pip-boutique-ingress-weu"
  location            = var.location
  resource_group_name = azurerm_resource_group.shared.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.tags
}

module "aks" {
  source                     = "../../modules/aks"
  location                   = var.location
  tags                       = local.tags
  resource_group_name        = azurerm_resource_group.shared.name
  cluster_name               = "aks-boutique-weu"
  dns_prefix                 = "aksboutiqueweu"
  kubernetes_version         = var.kubernetes_version
  aks_subnet_id              = module.network.aks_subnet_id
  log_analytics_workspace_id = module.log_analytics.workspace_id
  api_server_authorized_ip_ranges = var.api_server_authorized_ip_ranges
}

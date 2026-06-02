data "azurerm_kubernetes_service_versions" "region" {
  location = var.location
}

locals {
  tags = merge(
    var.tags,
    {
      owner = var.owner_email
    }
  )

  kubernetes_version = coalesce(var.kubernetes_version, data.azurerm_kubernetes_service_versions.region.default_version)
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
  source                          = "../../modules/aks"
  location                        = var.location
  tags                            = local.tags
  resource_group_name             = azurerm_resource_group.shared.name
  cluster_name                    = "aks-boutique-weu"
  dns_prefix                      = "aksboutiqueweu"
  kubernetes_version              = local.kubernetes_version
  create_workload_node_pools      = var.aks_create_workload_node_pools
  create_user_node_pool           = var.aks_create_user_node_pool
  user_pool                       = var.aks_user_pool
  system_pool                     = var.aks_system_pool
  aks_subnet_id                   = module.network.aks_subnet_id
  log_analytics_workspace_id      = module.log_analytics.workspace_id
  api_server_authorized_ip_ranges = var.api_server_authorized_ip_ranges

  # Ingress uses this PIP via Helm/GitOps, not via this module. Without an edge, destroy can try
  # to delete the PIP before the cluster LB releases it → PublicIPAddressCannotBeDeleted.
  depends_on = [azurerm_public_ip.ingress]
}

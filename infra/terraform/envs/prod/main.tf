locals {
  tags = merge(
    var.tags,
    { owner = var.owner_email }
  )
}

data "terraform_remote_state" "shared" {
  backend = "azurerm"

  config = {
    resource_group_name  = var.shared_state_resource_group_name
    storage_account_name = var.shared_state_storage_account_name
    container_name       = var.shared_state_container_name
    key                  = var.shared_state_key
  }
}

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "env" {
  name     = "rg-boutique-prod-weu"
  location = var.location
  tags     = local.tags
}

module "acr" {
  source = "../../modules/acr"

  location                = var.location
  tags                    = local.tags
  resource_group_name     = azurerm_resource_group.env.name
  registry_name           = "acrboutiqueprodweu"
  pe_subnet_id            = data.terraform_remote_state.shared.outputs.pe_subnet_id
  private_dns_zone_acr_id = data.terraform_remote_state.shared.outputs.private_dns_zone_acr_id
  kubelet_object_id       = data.terraform_remote_state.shared.outputs.kubelet_identity_object_id
  # Match stage/dev for operator/CI access to registry data-plane (private endpoint remains).
  public_network_access_enabled = true
}

resource "azurerm_role_assignment" "promotion_prod_acr_push" {
  count                = var.promotion_service_principal_object_id != "" ? 1 : 0
  scope                = module.acr.registry_id
  role_definition_name = "AcrPush"
  principal_id         = var.promotion_service_principal_object_id
}

# Reader on stage + prod RGs is created in the stage stack only (same principal+scope is unique in Azure).

module "keyvault" {
  source = "../../modules/keyvault"

  location                     = var.location
  tags                         = local.tags
  resource_group_name          = azurerm_resource_group.env.name
  keyvault_name                = "kv-boutique-prod-weu"
  tenant_id                    = data.azurerm_client_config.current.tenant_id
  pe_subnet_id                 = data.terraform_remote_state.shared.outputs.pe_subnet_id
  private_dns_zone_keyvault_id = data.terraform_remote_state.shared.outputs.private_dns_zone_keyvault_id
}

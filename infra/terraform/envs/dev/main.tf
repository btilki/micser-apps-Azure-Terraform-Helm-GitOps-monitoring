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
  name     = "rg-boutique-dev-weu"
  location = var.location
  tags     = local.tags
}

module "acr" {
  source = "../../modules/acr"

  location                  = var.location
  tags                      = local.tags
  resource_group_name       = azurerm_resource_group.env.name
  registry_name             = "acrboutiquedevweu"
  pe_subnet_id              = data.terraform_remote_state.shared.outputs.pe_subnet_id
  private_dns_zone_acr_id   = data.terraform_remote_state.shared.outputs.private_dns_zone_acr_id
  kubelet_object_id         = data.terraform_remote_state.shared.outputs.kubelet_identity_object_id
  public_network_access_enabled = false
}

module "keyvault" {
  source = "../../modules/keyvault"

  location                     = var.location
  tags                         = local.tags
  resource_group_name          = azurerm_resource_group.env.name
  keyvault_name                = "kv-boutique-dev-weu"
  tenant_id                    = data.azurerm_client_config.current.tenant_id
  pe_subnet_id                 = data.terraform_remote_state.shared.outputs.pe_subnet_id
  private_dns_zone_keyvault_id = data.terraform_remote_state.shared.outputs.private_dns_zone_keyvault_id
}

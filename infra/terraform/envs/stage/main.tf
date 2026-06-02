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

data "azurerm_resource_group" "prod" {
  name = "rg-boutique-prod-weu"
}

resource "azurerm_resource_group" "env" {
  name     = "rg-boutique-stage-weu"
  location = var.location
  tags     = local.tags
}

module "acr" {
  source = "../../modules/acr"

  location                = var.location
  tags                    = local.tags
  resource_group_name     = azurerm_resource_group.env.name
  registry_name           = "acrboutiquestageweu"
  pe_subnet_id            = data.terraform_remote_state.shared.outputs.pe_subnet_id
  private_dns_zone_acr_id = data.terraform_remote_state.shared.outputs.private_dns_zone_acr_id
  kubelet_object_id       = data.terraform_remote_state.shared.outputs.kubelet_identity_object_id
  # Match dev: allow public data-plane so `az acr` / docker from the internet works. Private endpoint remains for in-VNet traffic.
  public_network_access_enabled = true
}

resource "azurerm_role_assignment" "promotion_stage_acr_pull" {
  count                = var.promotion_service_principal_object_id != "" ? 1 : 0
  scope                = module.acr.registry_id
  role_definition_name = "AcrPull"
  principal_id         = var.promotion_service_principal_object_id
}

resource "azurerm_role_assignment" "promotion_stage_acr_push" {
  count                = var.promotion_service_principal_object_id != "" ? 1 : 0
  scope                = module.acr.registry_id
  role_definition_name = "AcrPush"
  principal_id         = var.promotion_service_principal_object_id
}

resource "azurerm_role_assignment" "promotion_reader_stage_rg" {
  count                = var.promotion_service_principal_object_id != "" ? 1 : 0
  scope                = azurerm_resource_group.env.id
  role_definition_name = "Reader"
  principal_id         = var.promotion_service_principal_object_id
}

resource "azurerm_role_assignment" "promotion_reader_prod_rg" {
  count                = var.promotion_service_principal_object_id != "" ? 1 : 0
  scope                = data.azurerm_resource_group.prod.id
  role_definition_name = "Reader"
  principal_id         = var.promotion_service_principal_object_id
}

module "keyvault" {
  source = "../../modules/keyvault"

  location                     = var.location
  tags                         = local.tags
  resource_group_name          = azurerm_resource_group.env.name
  keyvault_name                = "kv-boutique-stage-weu"
  tenant_id                    = data.azurerm_client_config.current.tenant_id
  pe_subnet_id                 = data.terraform_remote_state.shared.outputs.pe_subnet_id
  private_dns_zone_keyvault_id = data.terraform_remote_state.shared.outputs.private_dns_zone_keyvault_id
}

module "frontend_workload_identity" {
  source = "../../modules/workload_identity"

  location                  = var.location
  tags                      = local.tags
  resource_group_name       = azurerm_resource_group.env.name
  identity_name             = "id-boutique-stage-frontend-weu"
  oidc_issuer_url           = data.terraform_remote_state.shared.outputs.aks_oidc_issuer_url
  federated_credential_name = "fic-stage-frontend"
  federated_subject         = "system:serviceaccount:stage:frontend-stage"
  key_vault_id              = module.keyvault.vault_id
}

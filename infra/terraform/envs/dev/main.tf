locals {
  tags = merge(
    var.tags,
    { owner = var.owner_email }
  )
}

data "azurerm_client_config" "current" {}

data "terraform_remote_state" "shared" {
  backend = "azurerm"

  config = {
    resource_group_name  = var.shared_state_resource_group_name
    storage_account_name = var.shared_state_storage_account_name
    container_name       = var.shared_state_container_name
    key                  = var.shared_state_key
    use_azuread_auth     = true
    subscription_id      = data.azurerm_client_config.current.subscription_id
    tenant_id            = data.azurerm_client_config.current.tenant_id
  }
}

resource "azurerm_resource_group" "env" {
  name     = "rg-boutique-dev-weu"
  location = var.location
  tags     = local.tags
}

module "acr" {
  source = "../../modules/acr"

  location                = var.location
  tags                    = local.tags
  resource_group_name     = azurerm_resource_group.env.name
  registry_name           = "acrboutiquedevweu"
  pe_subnet_id            = data.terraform_remote_state.shared.outputs.pe_subnet_id
  private_dns_zone_acr_id = data.terraform_remote_state.shared.outputs.private_dns_zone_acr_id
  kubelet_object_id       = data.terraform_remote_state.shared.outputs.kubelet_identity_object_id
  # Temporarily enabled for Microsoft-hosted Azure DevOps CI access.
  public_network_access_enabled = true
}

resource "azurerm_role_assignment" "promotion_dev_acr_pull" {
  count                = var.promotion_service_principal_object_id != "" ? 1 : 0
  scope                = module.acr.registry_id
  role_definition_name = "AcrPull"
  principal_id         = var.promotion_service_principal_object_id
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

# Workload Identity for dev frontend → Key Vault (CSI SecretProviderClass v1).
module "frontend_workload_identity" {
  source = "../../modules/workload_identity"

  location                    = var.location
  tags                        = local.tags
  resource_group_name         = azurerm_resource_group.env.name
  identity_name               = "id-boutique-dev-frontend-weu"
  oidc_issuer_url             = data.terraform_remote_state.shared.outputs.aks_oidc_issuer_url
  federated_credential_name   = "fic-dev-frontend"
  federated_subject           = "system:serviceaccount:dev:frontend"
  key_vault_id                = module.keyvault.vault_id
}

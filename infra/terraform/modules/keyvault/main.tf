data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "main" {
  name                = var.keyvault_name
  location            = var.location
  resource_group_name = var.resource_group_name
  tenant_id           = var.tenant_id
  sku_name            = "standard"
  tags                = var.tags

  purge_protection_enabled      = var.purge_protection_enabled
  soft_delete_retention_days    = var.soft_delete_retention_days
  public_network_access_enabled = false
  enable_rbac_authorization     = true
}

resource "azurerm_private_endpoint" "kv" {
  name                = "pe-${var.keyvault_name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.pe_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-kv-${var.keyvault_name}"
    private_connection_resource_id = azurerm_key_vault.main.id
    is_manual_connection           = false
    subresource_names              = ["vault"]
  }

  private_dns_zone_group {
    name                 = "kv-dns"
    private_dns_zone_ids = [var.private_dns_zone_keyvault_id]
  }
}

resource "azurerm_role_assignment" "deployer_admin" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}

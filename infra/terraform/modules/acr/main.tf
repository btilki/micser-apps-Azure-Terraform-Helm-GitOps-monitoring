locals {
  # This module always creates a private endpoint. The registry must stay **Premium**:
  # - public access disabled requires Premium, and
  # - enabling public access must **not** downgrade to Standard while PEs exist (Azure returns 409).
  acr_sku = "Premium"
}

resource "azurerm_container_registry" "main" {
  name                = var.registry_name
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = local.acr_sku
  admin_enabled       = false
  tags                = var.tags

  public_network_access_enabled = var.public_network_access_enabled

  dynamic "georeplications" {
    for_each = local.acr_sku == "Premium" ? var.georeplications : []
    content {
      location = georeplications.value
    }
  }
}

resource "azurerm_private_endpoint" "acr" {
  name                = "pe-${var.registry_name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.pe_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-acr-${var.registry_name}"
    private_connection_resource_id = azurerm_container_registry.main.id
    is_manual_connection           = false
    subresource_names              = ["registry"]
  }

  private_dns_zone_group {
    name                 = "acr-dns"
    private_dns_zone_ids = [var.private_dns_zone_acr_id]
  }
}

resource "azurerm_role_assignment" "kubelet_acr_pull" {
  scope                = azurerm_container_registry.main.id
  role_definition_name = "AcrPull"
  principal_id         = var.kubelet_object_id
}

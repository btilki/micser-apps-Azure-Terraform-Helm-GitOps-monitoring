output "virtual_network_id" {
  value = azurerm_virtual_network.main.id
}

output "aks_subnet_id" {
  value = azurerm_subnet.aks.id
}

output "pe_subnet_id" {
  value = azurerm_subnet.pe.id
}

output "bastion_subnet_id" {
  value = azurerm_subnet.bastion.id
}

output "private_dns_zone_acr_id" {
  value = azurerm_private_dns_zone.acr.id
}

output "private_dns_zone_keyvault_id" {
  value = azurerm_private_dns_zone.keyvault.id
}

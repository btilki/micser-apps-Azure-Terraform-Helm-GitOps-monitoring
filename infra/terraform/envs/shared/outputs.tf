output "resource_group_name" {
  value = azurerm_resource_group.shared.name
}

output "location" {
  value = var.location
}

output "vnet_id" {
  value = module.network.virtual_network_id
}

output "aks_subnet_id" {
  value = module.network.aks_subnet_id
}

output "pe_subnet_id" {
  value = module.network.pe_subnet_id
}

output "private_dns_zone_acr_id" {
  value = module.network.private_dns_zone_acr_id
}

output "private_dns_zone_keyvault_id" {
  value = module.network.private_dns_zone_keyvault_id
}

output "kubelet_identity_object_id" {
  value = module.aks.kubelet_identity_object_id
}

output "aks_cluster_name" {
  value = module.aks.cluster_name
}

output "aks_oidc_issuer_url" {
  value = module.aks.oidc_issuer_url
}

output "ingress_public_ip" {
  value = azurerm_public_ip.ingress.ip_address
}

output "ingress_public_ip_id" {
  value = azurerm_public_ip.ingress.id
}

output "dns_zone_name_servers" {
  value = module.dns.name_servers
}

output "dns_zone_id" {
  value = module.dns.zone_id
}

output "log_analytics_workspace_id" {
  value = module.log_analytics.workspace_id
}

output "kube_config_raw" {
  value     = module.aks.kube_config_raw
  sensitive = true
}

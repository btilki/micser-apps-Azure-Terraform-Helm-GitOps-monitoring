output "resource_group_name" {
  value = azurerm_resource_group.env.name
}

output "acr_login_server" {
  value = module.acr.login_server
}

output "key_vault_uri" {
  value = module.keyvault.vault_uri
}

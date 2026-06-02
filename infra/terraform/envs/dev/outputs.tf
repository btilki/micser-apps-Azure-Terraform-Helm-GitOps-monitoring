output "resource_group_name" {
  value = azurerm_resource_group.env.name
}

output "acr_login_server" {
  value = module.acr.login_server
}

output "key_vault_uri" {
  value = module.keyvault.vault_uri
}

output "frontend_workload_identity_client_id" {
  description = "Set azure.workload.identity/client-id on frontend SA and SecretProviderClass clientID"
  value       = module.frontend_workload_identity.client_id
}

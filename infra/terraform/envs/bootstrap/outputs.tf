output "resource_group_name" {
  value = azurerm_resource_group.bootstrap.name
}

output "storage_account_name" {
  value = azurerm_storage_account.tfstate.name
}

output "container_names" {
  value = {
    shared = azurerm_storage_container.shared.name
    dev    = azurerm_storage_container.dev.name
    stage  = azurerm_storage_container.stage.name
    prod   = azurerm_storage_container.prod.name
  }
}

output "subscription_budget_id" {
  value       = try(azurerm_consumption_budget_subscription.monthly[0].id, null)
  description = "Set when enable_subscription_budget is true and notification emails are configured."
}

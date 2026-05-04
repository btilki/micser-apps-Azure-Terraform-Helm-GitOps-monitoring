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

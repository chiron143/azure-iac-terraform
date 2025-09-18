output "resource_group_name" {
  description = "Name of the created resource group"
  value       = azurerm_resource_group.main.name
}

output "webapp_url" {
  description = "Default hostname of the web app"
  value       = "https://${azurerm_linux_web_app.main.default_hostname}"
}

output "storage_account_name" {
  description = "Name of the storage account"
  value       = azurerm_storage_account.main.name
}
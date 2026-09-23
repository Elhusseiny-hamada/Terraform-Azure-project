output "resource_group_name" {
  value = azurerm_resource_group.rg.name
}

output "vnet_name" {
  value = azurerm_virtual_network.vnet.name
}

output "web_subnet_name" {
  value = azurerm_subnet.web.name
}

output "database_subnet_name" {
  value = azurerm_subnet.database.name
}

output "vmss_name" {
  value = azurerm_linux_virtual_machine_scale_set.web.name
}

output "vmss_instance_count" {
  value = var.vmss_instances
}

output "application_gateway_name" {
  value = azurerm_application_gateway.web.name
}

output "application_gateway_public_ip" {
  value = azurerm_public_ip.app_gateway.ip_address
}

output "sql_primary_server" {
  value = azurerm_mssql_server.primary.fully_qualified_domain_name
}

output "sql_secondary_server" {
  value = azurerm_mssql_server.secondary.fully_qualified_domain_name
}

output "sql_database_name" {
  value = azurerm_mssql_database.primary.name
}

output "storage_account_name" {
  value = azurerm_storage_account.storage.name
}

output "key_vault_name" {
  value = azurerm_key_vault.main.name
}

output "application_insights_name" {
  value = azurerm_application_insights.web.name
}

output "log_analytics_workspace_name" {
  value = azurerm_log_analytics_workspace.main.name
}
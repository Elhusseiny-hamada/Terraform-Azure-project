resource "azurerm_mssql_server" "primary" {
  name                         = var.sql_primary_server_name
  resource_group_name          = azurerm_resource_group.rg.name
  location                     = "Central US"
  version                      = "12.0"
  administrator_login          = var.sql_admin_username
  administrator_login_password = var.sql_admin_password

  minimum_tls_version = "1.2"

  public_network_access_enabled = false

  tags = {
    Environment = "Training"
    Project     = "Azure-Cloud-Project"
    Role        = "SQL-Primary"
  }
}

resource "azurerm_mssql_server" "secondary" {
  name                         = var.sql_secondary_server_name
  resource_group_name          = azurerm_resource_group.rg.name
  location                     = "UK West"
  version                      = "12.0"
  administrator_login          = var.sql_admin_username
  administrator_login_password = var.sql_admin_password

  minimum_tls_version = "1.2"

  public_network_access_enabled = false

  tags = {
    Environment = "Training"
    Project     = "Azure-Cloud-Project"
    Role        = "SQL-Secondary"
  }
}

resource "azurerm_mssql_database" "primary" {
  name      = var.sql_database_name
  server_id = azurerm_mssql_server.primary.id

  sku_name = "S0"

  storage_account_type = "Local"

  tags = {
    Environment = "Training"
    Project     = "Azure-Cloud-Project"
  }
}

resource "azurerm_mssql_failover_group" "sql" {
  name      = "sql-failover-group-01"
  server_id = azurerm_mssql_server.primary.id

  databases = [
    azurerm_mssql_database.primary.id
  ]

  partner_server {
    id = azurerm_mssql_server.secondary.id
  }

  read_write_endpoint_failover_policy {
    mode          = "Automatic"
    grace_minutes = 60
  }

  readonly_endpoint_failover_policy_enabled = false

  tags = {
    Environment = "Training"
    Project     = "Azure-Cloud-Project"
    Role        = "SQL-Failover"
  }
}
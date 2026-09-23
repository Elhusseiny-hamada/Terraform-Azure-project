resource "azurerm_private_dns_zone" "sql" {
  name                = "privatelink.database.windows.net"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "sql" {
  name                  = "sql-dns-link"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.sql.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
}

resource "azurerm_private_endpoint" "sql" {
  name                = "pe-sql-primary"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.database.id

  private_service_connection {
    name                           = "sql-private-connection"
    private_connection_resource_id = azurerm_mssql_server.primary.id
    is_manual_connection           = false
    subresource_names              = ["sqlServer"]
  }

  private_dns_zone_group {
    name = "sql-dns-zone-group"

    private_dns_zone_ids = [
      azurerm_private_dns_zone.sql.id
    ]
  }
}
resource "azurerm_private_dns_zone" "storage_blob" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "storage_blob" {
  name                  = "storage-blob-dns-link"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.storage_blob.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
}

resource "azurerm_private_endpoint" "storage_blob" {
  name                = "pe-storage-blob"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  subnet_id = azurerm_subnet.storage.id

  private_service_connection {
    name                           = "storage-blob-private-connection"
    private_connection_resource_id = azurerm_storage_account.storage.id

    is_manual_connection = false

    subresource_names = [
      "blob"
    ]
  }

  private_dns_zone_group {
    name = "storage-blob-dns-zone-group"

    private_dns_zone_ids = [
      azurerm_private_dns_zone.storage_blob.id
    ]
  }
}
resource "azurerm_private_dns_zone" "keyvault" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "keyvault" {
  name                  = "keyvault-dns-link"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.keyvault.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
}

resource "azurerm_private_endpoint" "keyvault" {
  name                = "pe-keyvault"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  subnet_id = azurerm_subnet.storage.id

  private_service_connection {
    name                           = "keyvault-private-connection"
    private_connection_resource_id = azurerm_key_vault.main.id

    is_manual_connection = false

    subresource_names = [
      "vault"
    ]
  }

  private_dns_zone_group {
    name = "keyvault-dns-zone-group"

    private_dns_zone_ids = [
      azurerm_private_dns_zone.keyvault.id
    ]
  }
}
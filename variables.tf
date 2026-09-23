variable "resource_group_name" {
  type        = string
  description = "Name of the Azure Resource Group"
}

variable "location" {
  type        = string
  description = "Azure region"
}

variable "vnet_name" {
  type        = string
  description = "Name of the Virtual Network"
}

variable "vnet_address_space" {
  type        = list(string)
  description = "VNet address space"
}

variable "app_gateway_subnet" {
  type        = string
  description = "Application Gateway subnet"
}

variable "web_subnet" {
  type        = string
  description = "Web subnet"
}

variable "database_subnet" {
  type        = string
  description = "Database subnet"
}

variable "storage_subnet" {
  type        = string
  description = "Storage subnet"
}
variable "vmss_name" {
  type        = string
  description = "Name of the Virtual Machine Scale Set"
}

variable "vm_size" {
  type        = string
  description = "VM size"
}

variable "vmss_instances" {
  type        = number
  description = "Initial number of VMSS instances"
}

variable "vm_admin_username" {
  type        = string
  description = "Admin username for the VMSS"
}

variable "vm_admin_password" {
  type        = string
  sensitive   = true
  description = "Admin password for the VMSS"
}
variable "storage_account_name" {
  type        = string
  description = "Globally unique Azure Storage Account name"
}

variable "sql_primary_server_name" {
  type        = string
  description = "Primary Azure SQL server name"
}

variable "sql_secondary_server_name" {
  type        = string
  description = "Secondary Azure SQL server name"
}

variable "sql_database_name" {
  type        = string
  description = "Azure SQL database name"
}

variable "sql_admin_username" {
  type        = string
  description = "Azure SQL administrator username"
}

variable "sql_admin_password" {
  type        = string
  sensitive   = true
  description = "Azure SQL administrator password"
}

variable "key_vault_name" {
  type        = string
  description = "Globally unique Azure Key Vault name"
}
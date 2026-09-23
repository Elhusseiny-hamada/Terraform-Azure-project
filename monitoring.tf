resource "azurerm_log_analytics_workspace" "main" {
  name                = "law-azure-cloud-project"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  sku               = "PerGB2018"
  retention_in_days = 30

  tags = {
    Environment = "Training"
    Project     = "Azure-Cloud-Project"
  }
}

resource "azurerm_application_insights" "web" {
  name                = "appi-azure-cloud-project"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  application_type = "web"

  workspace_id = azurerm_log_analytics_workspace.main.id

  tags = {
    Environment = "Training"
    Project     = "Azure-Cloud-Project"
  }
}

resource "azurerm_monitor_metric_alert" "vmss_cpu" {
  name                = "vmss-high-cpu"
  resource_group_name = azurerm_resource_group.rg.name
  scopes              = [azurerm_linux_virtual_machine_scale_set.web.id]

  description = "Alert when VMSS average CPU is high."

  severity    = 2
  frequency   = "PT1M"
  window_size = "PT5M"

  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachineScaleSets"
    metric_name      = "Percentage CPU"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 80
  }

  tags = {
    Environment = "Training"
    Project     = "Azure-Cloud-Project"
  }
}

resource "azurerm_linux_virtual_machine_scale_set" "web" {
  name                = var.vmss_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  sku       = var.vm_size
  instances = var.vmss_instances
  identity {
    type = "SystemAssigned"
  }

  admin_username                  = var.vm_admin_username
  admin_password                  = var.vm_admin_password
  disable_password_authentication = false

  upgrade_mode = "Automatic"

  custom_data = filebase64("${path.module}/bootstrap.sh")

  network_interface {
    name    = "web-nic"
    primary = true

    ip_configuration {
      name      = "web-ip-config"
      primary   = true
      subnet_id = azurerm_subnet.web.id

      application_gateway_backend_address_pool_ids = [
        for pool in azurerm_application_gateway.web.backend_address_pool :
        pool.id
        if pool.name == "web-backend-pool"
      ]
    }
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  tags = {
    Environment = "Training"
    Project     = "Azure-Cloud-Project"
    Role        = "Web"
  }
}
resource "azurerm_public_ip" "app_gateway" {
  name                = "pip-app-gateway"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  allocation_method = "Static"
  sku               = "Standard"
  domain_name_label = "vodafone-customer-portal"
}
resource "tls_private_key" "app_gateway" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "app_gateway" {
  private_key_pem = tls_private_key.app_gateway.private_key_pem

  subject {
    common_name  = azurerm_public_ip.app_gateway.ip_address
    organization = "Azure Cloud Project"
  }

  validity_period_hours = 8760

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]

  ip_addresses = [
    azurerm_public_ip.app_gateway.ip_address
  ]
}

resource "pkcs12_from_pem" "app_gateway" {
  password        = "AzureCloud@2026"
  cert_pem        = tls_self_signed_cert.app_gateway.cert_pem
  private_key_pem = tls_private_key.app_gateway.private_key_pem
}

resource "azurerm_application_gateway" "web" {
  name                = "agw-web"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  firewall_policy_id  = azurerm_web_application_firewall_policy.web.id


  sku {
    name = "WAF_v2"
    tier = "WAF_v2"

  }


  autoscale_configuration {
    min_capacity = 2
    max_capacity = 5
  }
  ssl_certificate {
    name     = "agw-ssl-cert"
    data     = pkcs12_from_pem.app_gateway.result
    password = pkcs12_from_pem.app_gateway.password
  }

  gateway_ip_configuration {
    name      = "gateway-ip-config"
    subnet_id = azurerm_subnet.app_gateway.id
  }

  frontend_port {
    name = "http-port"
    port = 80
  }

  frontend_port {
    name = "https-port"
    port = 443
  }

  frontend_ip_configuration {
    name                 = "public-frontend"
    public_ip_address_id = azurerm_public_ip.app_gateway.id
  }

  backend_address_pool {
    name = "web-backend-pool"
  }

  backend_http_settings {
    name                  = "web-http-settings"
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 30
    probe_name            = "web-health-probe"
  }

  http_listener {
    name                           = "http-listener"
    frontend_ip_configuration_name = "public-frontend"
    frontend_port_name             = "http-port"
    protocol                       = "Http"
  }
  http_listener {
    name                           = "https-listener"
    frontend_ip_configuration_name = "public-frontend"
    frontend_port_name             = "https-port"
    protocol                       = "Https"
    ssl_certificate_name           = "agw-ssl-cert"
  }

  request_routing_rule {
    name                       = "web-routing-rule"
    priority                   = 100
    rule_type                  = "Basic"
    http_listener_name         = "http-listener"
    backend_address_pool_name  = "web-backend-pool"
    backend_http_settings_name = "web-http-settings"
  }
  request_routing_rule {
    name                       = "web-https-routing-rule"
    priority                   = 110
    rule_type                  = "Basic"
    http_listener_name         = "https-listener"
    backend_address_pool_name  = "web-backend-pool"
    backend_http_settings_name = "web-http-settings"
  }
  probe {
    name                = "web-health-probe"
    protocol            = "Http"
    host                = "127.0.0.1"
    path                = "/api/health"
    interval            = 30
    timeout             = 30
    unhealthy_threshold = 3
  }



  tags = {
    Environment = "Training"
    Project     = "Azure-Cloud-Project"
    Role        = "Application-Gateway"
  }

  depends_on = [
    azurerm_subnet_network_security_group_association.app_gateway
  ]
}

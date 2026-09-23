terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.3"
    }

    pkcs12 = {
      source  = "chilicat/pkcs12"
      version = "~> 0.4"
    }
  }
}


provider "azurerm" {
  features {}
}


terraform {
  required_version = ">= 1.5"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

module "vnet" {
  source = "../.."

  name                = "example-vnet"
  resource_group_name = "example-rg"
  location            = "eastus"
  address_space       = ["10.10.0.0/16"]
  dns_servers         = ["10.10.0.4", "10.10.0.5"]

  tags = {
    Environment = "sandbox"
    ManagedBy   = "terraform"
  }
}

output "vnet_id" {
  value = module.vnet.id
}

# Note: `azurerm_virtual_network` also accepts inline `subnet` blocks, but that
# attribute is authoritative — declaring it makes Terraform delete every subnet
# it does not list, including subnets managed as standalone `azurerm_subnet`
# resources. This module deliberately never sets it, so subnets stay owned by
# whatever manages them. See README.md ("Subnets, peerings and route tables").
resource "azurerm_virtual_network" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  address_space       = var.address_space
  dns_servers         = var.dns_servers

  dynamic "ddos_protection_plan" {
    for_each = var.ddos_protection_plan == null ? [] : [var.ddos_protection_plan]

    content {
      id     = ddos_protection_plan.value.id
      enable = ddos_protection_plan.value.enable
    }
  }

  tags = var.tags
}

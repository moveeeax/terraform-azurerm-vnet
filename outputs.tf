output "id" {
  description = "ID of the virtual network."
  value       = azurerm_virtual_network.this.id
}

output "name" {
  description = "Name of the virtual network."
  value       = azurerm_virtual_network.this.name
}

output "resource_group_name" {
  description = "Name of the resource group holding the virtual network. Companion subnet and peering resources need it alongside the virtual network name."
  value       = azurerm_virtual_network.this.resource_group_name
}

output "location" {
  description = "Azure region the virtual network was created in."
  value       = azurerm_virtual_network.this.location
}

output "address_space" {
  description = "Address ranges assigned to the virtual network, in the order they were declared."

  # Deliberately sourced from the input rather than the resource attribute.
  # `azurerm_virtual_network.address_space` is list(string) up to azurerm 3.117
  # and set(string) from azurerm 4.0 onwards, so forwarding the attribute makes
  # this output change type — and lose ordering — purely because a consumer
  # upgraded the provider, breaking `module.vnet.address_space[0]`. The attribute
  # is required and not computed, so the input is exactly what gets applied.
  value = var.address_space
}

output "dns_servers" {
  description = "Custom DNS servers configured on the virtual network. Empty when Azure-provided DNS is in use."
  value       = azurerm_virtual_network.this.dns_servers
}

output "guid" {
  description = "GUID of the virtual network."
  value       = azurerm_virtual_network.this.guid
}

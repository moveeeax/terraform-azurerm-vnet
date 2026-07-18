variable "name" {
  description = "Name of the virtual network."
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group in which to create the virtual network."
  type        = string
}

variable "location" {
  description = "Azure region in which to create the virtual network."
  type        = string
}

variable "address_space" {
  description = "List of IPv4/IPv6 address ranges, in CIDR notation, assigned to the virtual network."
  type        = list(string)
  default     = ["10.0.0.0/16"]

  validation {
    condition     = length(var.address_space) > 0
    error_message = "At least one address space must be provided."
  }
}

variable "dns_servers" {
  description = "List of custom DNS server IP addresses for the virtual network. Empty uses Azure-provided DNS."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Map of tags applied to the virtual network."
  type        = map(string)
  default     = {}
}

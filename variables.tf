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

  validation {
    condition     = alltrue([for cidr in var.address_space : can(cidrhost(cidr, 0))])
    error_message = "Every entry in address_space must be a valid IPv4 or IPv6 CIDR range, for example \"10.0.0.0/16\"."
  }

  # Azure stores the masked network address, so a prefix carrying host bits
  # ("10.0.0.5/16") comes back as "10.0.0.0/16" and produces a permanent diff.
  # Comparing against the same address masked to a host prefix normalises
  # formatting, so shorthand IPv6 is not falsely rejected.
  validation {
    condition = alltrue([
      for cidr in var.address_space : try(
        cidrhost(cidr, 0) == cidrhost("${split("/", cidr)[0]}/${strcontains(cidr, ":") ? 128 : 32}", 0),
        true
      )
    ])
    error_message = "Every entry in address_space must be the network address of its range, for example \"10.0.0.0/16\" rather than \"10.0.0.5/16\"."
  }

  # Azure rejects a virtual network whose address prefixes overlap. Two ranges
  # overlap exactly when masking both to the shorter of the two prefix lengths
  # yields the same network address.
  validation {
    condition = alltrue([
      for pair in setproduct(range(length(var.address_space)), range(length(var.address_space))) :
      pair[0] >= pair[1] ? true : try(
        cidrhost("${split("/", var.address_space[pair[0]])[0]}/${min(tonumber(split("/", var.address_space[pair[0]])[1]), tonumber(split("/", var.address_space[pair[1]])[1]))}", 0)
        !=
        cidrhost("${split("/", var.address_space[pair[1]])[0]}/${min(tonumber(split("/", var.address_space[pair[0]])[1]), tonumber(split("/", var.address_space[pair[1]])[1]))}", 0),
        true
      )
    ])
    error_message = "Entries in address_space must not overlap one another."
  }
}

variable "dns_servers" {
  description = "List of custom DNS server IP addresses for the virtual network. Empty uses Azure-provided DNS."
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for ip in var.dns_servers : can(cidrhost("${ip}/${strcontains(ip, ":") ? 128 : 32}", 0))
    ])
    error_message = "Every entry in dns_servers must be a bare IPv4 or IPv6 address, for example \"10.0.0.4\", not a CIDR range."
  }

  validation {
    condition     = length(distinct(var.dns_servers)) == length(var.dns_servers)
    error_message = "dns_servers must not contain duplicate addresses."
  }
}

variable "ddos_protection_plan" {
  description = <<-EOT
    Optional association with an existing DDoS network protection plan. `id` is the
    resource ID of an `azurerm_network_ddos_protection_plan`; `enable` keeps the
    association while turning protection off when set to `false`. Leaving this null
    keeps the virtual network on Azure's basic, infrastructure-level DDoS protection.
    The association can only be expressed on the virtual network resource itself, so
    a companion module cannot add it.
  EOT

  type = object({
    id     = string
    enable = optional(bool, true)
  })
  default = null

  validation {
    condition     = var.ddos_protection_plan == null ? true : can(regex("^/subscriptions/[^/]+/", var.ddos_protection_plan.id))
    error_message = "ddos_protection_plan.id must be the full Azure resource ID of a DDoS protection plan, starting with \"/subscriptions/\"."
  }
}

variable "tags" {
  description = "Map of tags applied to the virtual network."
  type        = map(string)
  default     = {}
}

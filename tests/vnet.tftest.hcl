# Unit tests for the module. These run with no Azure credentials and no network
# because the provider is mocked.
#
# Test-only requirement: `mock_provider` needs Terraform >= 1.7 / OpenTofu >= 1.7.
# The module itself still only requires the version declared in versions.tf.
#
#   terraform test

mock_provider "azurerm" {}

variables {
  name                = "unit-test-vnet"
  resource_group_name = "unit-test-rg"
  location            = "eastus"
}

run "defaults_are_minimal_and_safe" {
  command = plan

  assert {
    condition     = toset(azurerm_virtual_network.this.address_space) == toset(["10.0.0.0/16"])
    error_message = "Default address_space must stay 10.0.0.0/16."
  }

  # azurerm 3.x types this attribute list(string) and azurerm 4.x set(string).
  # The output must stay an ordered list(string) on both so that indexing it
  # does not break when a consumer upgrades the provider.
  assert {
    condition     = output.address_space == tolist(["10.0.0.0/16"])
    error_message = "Output address_space must be an ordered list(string) regardless of the azurerm provider major version."
  }

  assert {
    condition     = length(azurerm_virtual_network.this.dns_servers) == 0
    error_message = "No custom DNS servers must be configured by default; Azure-provided DNS is the default."
  }

  assert {
    condition     = length(azurerm_virtual_network.this.ddos_protection_plan) == 0
    error_message = "No DDoS protection plan association must be emitted when var.ddos_protection_plan is null."
  }

  assert {
    condition     = length(azurerm_virtual_network.this.tags) == 0
    error_message = "No tags must be applied by default."
  }
}

run "required_inputs_reach_the_resource" {
  command = plan

  assert {
    condition     = azurerm_virtual_network.this.name == "unit-test-vnet"
    error_message = "var.name must be passed through to the virtual network."
  }

  assert {
    condition     = azurerm_virtual_network.this.resource_group_name == "unit-test-rg"
    error_message = "var.resource_group_name must be passed through to the virtual network."
  }

  assert {
    condition     = azurerm_virtual_network.this.location == "eastus"
    error_message = "var.location must be passed through to the virtual network."
  }
}

run "custom_dns_servers_are_applied_in_order" {
  command = plan

  variables {
    dns_servers = ["10.0.0.4", "10.0.0.5", "2001:db8::4"]
  }

  assert {
    condition     = azurerm_virtual_network.this.dns_servers == tolist(["10.0.0.4", "10.0.0.5", "2001:db8::4"])
    error_message = "Custom DNS servers must reach the resource unchanged and in the declared order; Azure treats the first entry as primary."
  }
}

run "multiple_non_overlapping_ranges_are_accepted" {
  command = plan

  variables {
    address_space = ["10.0.0.0/16", "10.1.0.0/16", "2001:db8::/48"]
  }

  assert {
    condition     = length(azurerm_virtual_network.this.address_space) == 3
    error_message = "Non-overlapping IPv4 and IPv6 ranges must all be accepted."
  }

  assert {
    condition     = output.address_space == tolist(["10.0.0.0/16", "10.1.0.0/16", "2001:db8::/48"])
    error_message = "Output address_space must preserve the declared order."
  }
}

run "adjacent_ranges_are_not_treated_as_overlapping" {
  command = plan

  variables {
    address_space = ["10.0.0.0/24", "10.0.1.0/24"]
  }

  assert {
    condition     = length(azurerm_virtual_network.this.address_space) == 2
    error_message = "Adjacent but distinct ranges must not be rejected as overlapping."
  }
}

run "ddos_protection_plan_is_wired_and_enabled_by_default" {
  command = plan

  variables {
    ddos_protection_plan = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/unit-test-rg/providers/Microsoft.Network/ddosProtectionPlans/unit-test-plan"
    }
  }

  assert {
    condition     = length(azurerm_virtual_network.this.ddos_protection_plan) == 1
    error_message = "A DDoS protection plan association must be emitted when var.ddos_protection_plan is set."
  }

  assert {
    condition     = azurerm_virtual_network.this.ddos_protection_plan[0].enable == true
    error_message = "Associating a DDoS protection plan must enable it unless explicitly disabled."
  }

  assert {
    condition     = azurerm_virtual_network.this.ddos_protection_plan[0].id == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/unit-test-rg/providers/Microsoft.Network/ddosProtectionPlans/unit-test-plan"
    error_message = "The DDoS protection plan resource ID must be passed through unchanged."
  }
}

run "ddos_protection_plan_can_be_associated_but_disabled" {
  command = plan

  variables {
    ddos_protection_plan = {
      id     = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/unit-test-rg/providers/Microsoft.Network/ddosProtectionPlans/unit-test-plan"
      enable = false
    }
  }

  assert {
    condition     = azurerm_virtual_network.this.ddos_protection_plan[0].enable == false
    error_message = "enable = false must reach the resource so protection can be suspended without dropping the association."
  }
}

run "rejects_empty_address_space" {
  command = plan

  variables {
    address_space = []
  }

  expect_failures = [var.address_space]
}

run "rejects_malformed_cidr" {
  command = plan

  variables {
    address_space = ["10.0.0.0/33"]
  }

  expect_failures = [var.address_space]
}

run "rejects_bare_ip_without_prefix" {
  command = plan

  variables {
    address_space = ["10.0.0.0"]
  }

  expect_failures = [var.address_space]
}

run "rejects_address_space_with_host_bits_set" {
  command = plan

  variables {
    address_space = ["10.0.0.5/16"]
  }

  expect_failures = [var.address_space]
}

run "rejects_identical_address_spaces" {
  command = plan

  variables {
    address_space = ["10.0.0.0/16", "10.0.0.0/16"]
  }

  expect_failures = [var.address_space]
}

run "rejects_contained_address_space" {
  command = plan

  variables {
    address_space = ["10.0.0.0/16", "10.0.1.0/24"]
  }

  expect_failures = [var.address_space]
}

run "rejects_containing_address_space_declared_second" {
  command = plan

  variables {
    address_space = ["10.0.1.0/24", "10.0.0.0/16"]
  }

  expect_failures = [var.address_space]
}

run "rejects_overlapping_ipv6_address_space" {
  command = plan

  variables {
    address_space = ["2001:db8::/32", "2001:db8:1::/48"]
  }

  expect_failures = [var.address_space]
}

run "rejects_dns_server_given_as_cidr" {
  command = plan

  variables {
    dns_servers = ["10.0.0.4/32"]
  }

  expect_failures = [var.dns_servers]
}

run "rejects_dns_server_that_is_not_an_ip" {
  command = plan

  variables {
    dns_servers = ["ns1.example.internal"]
  }

  expect_failures = [var.dns_servers]
}

run "rejects_duplicate_dns_servers" {
  command = plan

  variables {
    dns_servers = ["10.0.0.4", "10.0.0.4"]
  }

  expect_failures = [var.dns_servers]
}

run "rejects_ddos_protection_plan_name_instead_of_resource_id" {
  command = plan

  variables {
    ddos_protection_plan = {
      id = "unit-test-plan"
    }
  }

  expect_failures = [var.ddos_protection_plan]
}

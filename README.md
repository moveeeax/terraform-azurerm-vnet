# terraform-azurerm-vnet

Terraform module that manages an [Azure](https://azure.microsoft.com/) virtual
network. It creates a single virtual network with a configurable address space
and optional custom DNS servers, exposing its ID and GUID so companion modules
(subnets, peerings, route tables) can build on top of it.

## Usage

```hcl
module "vnet" {
  source = "github.com/cybercapybara/terraform-azurerm-vnet"

  name                = "prod-vnet"
  resource_group_name = "prod-rg"
  location            = "eastus"
  address_space       = ["10.0.0.0/16"]

  tags = {
    Environment = "production"
    ManagedBy   = "terraform"
  }
}
```

A runnable example lives in [`examples/basic`](examples/basic).

## Requirements

| Name      | Version  |
|-----------|----------|
| terraform | >= 1.5   |
| azurerm   | >= 3.0   |

## Inputs

| Name                  | Description                                                                       | Type           | Default             | Required |
|-----------------------|-----------------------------------------------------------------------------------|----------------|---------------------|:--------:|
| `name`                | Name of the virtual network.                                                      | `string`       | n/a                 |   yes    |
| `resource_group_name` | Name of the resource group in which to create the virtual network.                | `string`       | n/a                 |   yes    |
| `location`            | Azure region in which to create the virtual network.                              | `string`       | n/a                 |   yes    |
| `address_space`       | List of address ranges, in CIDR notation, assigned to the virtual network.        | `list(string)` | `["10.0.0.0/16"]`   |    no    |
| `dns_servers`         | List of custom DNS server IP addresses. Empty uses Azure-provided DNS.            | `list(string)` | `[]`                |    no    |
| `tags`                | Map of tags applied to the virtual network.                                       | `map(string)`  | `{}`                |    no    |

## Outputs

| Name            | Description                                    |
|-----------------|------------------------------------------------|
| `id`            | ID of the virtual network.                     |
| `name`          | Name of the virtual network.                   |
| `address_space` | Address ranges assigned to the virtual network.|
| `guid`          | GUID of the virtual network.                   |

## License

[MIT](LICENSE)

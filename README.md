# terraform-azurerm-vnet

Terraform module that manages an [Azure](https://azure.microsoft.com/) virtual
network. It creates a single virtual network with a configurable address space,
optional custom DNS servers and an optional DDoS protection plan association,
exposing its ID, name, location, resource group and GUID so companion modules
(subnets, peerings, route tables) can build on top of it.

## Usage

```hcl
module "vnet" {
  source = "github.com/moveeeax/terraform-azurerm-vnet"

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

### Custom DNS servers

The list order is significant: Azure hands the addresses to VM NICs in the order
given, so the first entry is the primary resolver. Leaving `dns_servers` empty
keeps the virtual network on Azure-provided DNS.

```hcl
dns_servers = ["10.0.0.4", "10.0.0.5"]
```

### DDoS network protection

By default a virtual network only gets Azure's basic, infrastructure-level DDoS
protection. Associating a DDoS network protection plan is the only way to enable
the paid tier, and — unlike subnets or peerings — it can only be expressed on the
virtual network resource itself, so no companion module can add it later.

```hcl
module "vnet" {
  # ...

  ddos_protection_plan = {
    id = azurerm_network_ddos_protection_plan.this.id
    # enable defaults to true; set false to keep the association while
    # suspending protection.
  }
}
```

The plan is billed per plan, not per virtual network, so one plan is normally
shared across every virtual network in a tenant.

## Subnets, peerings and route tables

This module intentionally manages **only** the virtual network. Subnets and
peerings belong in separate resources or companion modules, wired up with the
`name`, `resource_group_name` and `location` outputs.

The reason matters: `azurerm_virtual_network` accepts inline `subnet` blocks, but
that attribute is **authoritative**. As soon as a configuration declares even one
inline `subnet`, Terraform takes ownership of the whole set and will delete every
subnet not listed there — including subnets managed elsewhere as standalone
`azurerm_subnet` resources. Mixing the two styles produces a permanent plan diff
where each apply fights the other, and silently destroys subnets in between.
This module therefore never sets `subnet`, which leaves the attribute computed
and subnets owned by whatever created them.

The same applies to peerings: `azurerm_virtual_network_peering` is one resource
per direction. Peering is not symmetric, so each side is configured separately:

- `allow_forwarded_traffic` — set on the **receiving** side, to accept traffic
  that did not originate in the peer's own address space.
- `allow_gateway_transit` — set on the side that **owns** the gateway.
- `use_remote_gateways` — set on the side that **consumes** the peer's gateway.

`allow_gateway_transit` and `use_remote_gateways` are counterparts: exactly one
side sets each, and both sides must never set `use_remote_gateways` at once.

## Input validation

Bad addressing is rejected at plan time rather than surfacing as an opaque Azure
API error minutes into an apply. The module rejects:

- `address_space` entries that are not valid IPv4/IPv6 CIDR ranges.
- `address_space` entries carrying host bits (`10.0.0.5/16`). Azure stores the
  masked network address, so these otherwise produce a permanent plan diff.
- `address_space` entries that overlap one another, which Azure refuses.
- `dns_servers` entries that are not bare IP addresses, or that repeat.
- a `ddos_protection_plan.id` that is not a full Azure resource ID.

## Requirements

| Name      | Version  |
|-----------|----------|
| terraform | >= 1.5   |
| azurerm   | >= 3.0   |

The module is exercised against azurerm 3.0.0, 3.117.1, 4.0.0 and the current
4.x release. Running the test suite additionally needs Terraform or OpenTofu
>= 1.7 for `mock_provider`; the module itself does not.

## Inputs

| Name                   | Description                                                                       | Type                                              | Default             | Required |
|------------------------|-----------------------------------------------------------------------------------|---------------------------------------------------|---------------------|:--------:|
| `name`                 | Name of the virtual network.                                                      | `string`                                          | n/a                 |   yes    |
| `resource_group_name`  | Name of the resource group in which to create the virtual network.                | `string`                                          | n/a                 |   yes    |
| `location`             | Azure region in which to create the virtual network.                              | `string`                                          | n/a                 |   yes    |
| `address_space`        | List of address ranges, in CIDR notation, assigned to the virtual network.        | `list(string)`                                    | `["10.0.0.0/16"]`   |    no    |
| `dns_servers`          | List of custom DNS server IP addresses. Empty uses Azure-provided DNS.            | `list(string)`                                    | `[]`                |    no    |
| `ddos_protection_plan` | Association with an existing DDoS network protection plan.                        | `object({ id = string, enable = optional(bool) })` | `null`              |    no    |
| `tags`                 | Map of tags applied to the virtual network.                                       | `map(string)`                                     | `{}`                |    no    |

## Outputs

| Name                  | Description                                                          |
|-----------------------|----------------------------------------------------------------------|
| `id`                  | ID of the virtual network.                                           |
| `name`                | Name of the virtual network.                                         |
| `resource_group_name` | Name of the resource group holding the virtual network.              |
| `location`            | Azure region the virtual network was created in.                     |
| `address_space`       | Address ranges assigned, as `list(string)`, in the declared order.   |
| `dns_servers`         | Custom DNS servers configured, empty when Azure-provided DNS is used.|
| `guid`                | GUID of the virtual network.                                         |

`address_space` is deliberately sourced from the module input rather than from
the resource attribute: the provider types that attribute `list(string)` up to
azurerm 3.117 and `set(string)` from azurerm 4.0 onwards. Forwarding it would
change this output's type — and drop its ordering — purely because a consumer
upgraded the provider, breaking expressions such as `module.vnet.address_space[0]`.

## Development

```sh
terraform fmt -recursive
terraform init -backend=false && terraform validate
terraform test        # unit tests, mocked provider, no Azure credentials needed
tflint --recursive
```

## License

[MIT](LICENSE)

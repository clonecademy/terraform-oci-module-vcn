# Virtual Cloud Network — OCI Terraform Module

A Terraform module that provisions an Oracle Cloud Infrastructure (OCI) Virtual Cloud Network (VCN) with a public subnet, a private subnet, and the gateways and routing each one needs.

## What it creates

| Resource | Name | Purpose |
|---|---|---|
| VCN | `main-vcn` | DNS label `mainvcn`, default CIDR `10.0.0.0/16` |
| Internet gateway | `main-internet-gateway` | Inbound and outbound internet access for the public subnet |
| NAT gateway | `main-nat-gateway` | Outbound-only internet access for the private subnet |
| Service gateway | `main-service-gateway` | Private access to all Oracle Services Network services (Object Storage, etc.) |
| Public subnet | `main-public-subnet` | DNS label `public`, default CIDR `10.0.0.0/24`, public IPs allowed |
| Private subnet | `main-private-subnet` | DNS label `private`, default CIDR `10.0.1.0/24`, public IPs prohibited |
| Log group | `main-vcn-flow-logs` | Holds the VCN flow log |
| VCN flow log | `main-vcn-flow-log` | Flow logs for the whole VCN (both subnets), category `all` |

Routing:

- **Public subnet:** `0.0.0.0/0` goes to the internet gateway. This uses the VCN's default route table.
- **Private subnet:** `0.0.0.0/0` goes to the NAT gateway, and Oracle Services Network traffic goes to the service gateway. This uses a dedicated route table.

Both subnets use the VCN's default DHCP options.

## Usage

```hcl
module "vcn" {
  source = "git::https://github.com/clonecademy/terraform-oci-module-vcn.git?ref=v0.1.0"

  compartment_id = var.compartment_id

  # Optional; defaults shown
  vcn_cidr_blocks                 = ["10.0.0.0/16"]
  public_subnet_cidr_block        = "10.0.0.0/24"
  private_subnet_cidr_block       = "10.0.1.0/24"
  vcn_flow_logs_retention_in_days = 30
}
```

The module doesn't configure the `oci` provider. Configure it in your root module, as with any OCI provider setup.

### Requirements

| Name | Version |
|---|---|
| Terraform | `~> 1.16.0` |
| `oracle/oci` provider | `~> 9.1.0` |

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `compartment_id` | `string` | — (required) | OCID of the compartment where the VCN and its networking resources are created. |
| `vcn_cidr_blocks` | `list(string)` | `["10.0.0.0/16"]` | IPv4 CIDR blocks for the VCN. Must be a non-empty list. Both subnet CIDR blocks must fall inside these blocks. |
| `public_subnet_cidr_block` | `string` | `"10.0.0.0/24"` | IPv4 CIDR block of the public subnet. |
| `private_subnet_cidr_block` | `string` | `"10.0.1.0/24"` | IPv4 CIDR block of the private subnet. |
| `vcn_flow_logs_retention_in_days` | `number` | `30` | Retention period for the VCN flow log. OCI Logging only accepts 30-day increments up to 180 (30, 60, 90, 120, 150, 180). |

Every CIDR input must be valid IPv4 CIDR notation, or the module fails validation.

## Outputs

| Name | Description |
|---|---|
| `vcn_id` | OCID of the VCN. |
| `public_subnet_id` | OCID of the public subnet. |
| `private_subnet_id` | OCID of the private subnet. |
| `internet_gateway_id` | OCID of the internet gateway. |
| `nat_gateway_id` | OCID of the NAT gateway. |
| `nat_gateway_public_ip` | Public IP address that private subnet traffic is translated to. Add it to allowlists on external services. |
| `service_gateway_id` | OCID of the service gateway. |
| `oracle_services_network_cidr_block` | Service CIDR label that is routed to the service gateway. |
| `vcn_flow_log_group_id` | OCID of the log group containing the VCN flow log. |
| `vcn_flow_log_id` | OCID of the VCN flow log. |

## Security

Security lists apply to every VNIC in a subnet, so this module keeps them minimal:

| Subnet | Ingress | Egress |
|---|---|---|
| Public | ICMP type 3 code 4 (path MTU discovery) from anywhere, and ICMP type 3 from within the VCN | All traffic |
| Private | TCP 22 (SSH) from within the VCN, ICMP type 3 code 4 from anywhere, and ICMP type 3 from within the VCN | All traffic |

**The public subnet doesn't open any TCP or UDP ports, including SSH, HTTP, and HTTPS.** To expose a host, attach a [network security group](https://docs.oracle.com/en-us/iaas/Content/Network/Concepts/networksecuritygroups.htm) to it. Create the group in your own configuration using `module.vcn.vcn_id`. For example:

```hcl
resource "oci_core_network_security_group" "web" {
  compartment_id = var.compartment_id
  vcn_id         = module.vcn.vcn_id
  display_name   = "web"
}

resource "oci_core_network_security_group_security_rule" "https" {
  network_security_group_id = oci_core_network_security_group.web.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = "0.0.0.0/0"
  source_type               = "CIDR_BLOCK"

  tcp_options {
    destination_port_range {
      min = 443
      max = 443
    }
  }
}
```

Hosts in the private subnet accept SSH from anywhere in the VCN, for example from a bastion in the public subnet.

## Logging

The module enables a VCN flow log (category `all`) covering both subnets, in its own log group. OCI's Logging service gives Always Free tenancies 10 GB/month of ingestion at no cost, shared across every log in the tenancy — not just this one. A high-traffic VCN, or other logs sharing the tenancy, can exceed that allowance; ingestion beyond it is billed at $0.05/GB. This module has no way to cap ingestion from the outside, so watch usage if you're relying on staying free.

## Limitations

- Display names (`main-*`) and DNS labels (`mainvcn`, `public`, `private`) are hardcoded and can't be changed. If you create several instances of this module, their resources will share the same names.
- The module always creates exactly one public subnet and one private subnet, both regional.
- Only IPv4 is supported.
- This module manages the VCN's default route table and default security list. Don't also manage them elsewhere.

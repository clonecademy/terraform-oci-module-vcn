# AGENTS.md

This file provides guidance to agents when working with code in this repository.

## What this is

A reusable Terraform module that provisions an Oracle Cloud Infrastructure (OCI) Virtual Cloud Network with a public subnet, a private subnet, and internet, NAT, and service gateways. It's a root-less module: there is no provider block, backend, or `.tfvars`. The caller supplies the `oci` provider configuration and `compartment_id`, the only required input.

Version pins live in `versions.tf`: Terraform `~> 1.16.0`, `oracle/oci` provider `~> 9.1.0`. `.terraform.lock.hcl` is gitignored on purpose, since modules don't commit lockfiles.

## Commands

There is no test suite or CI. Check changes with:

```sh
terraform init -backend=false   # fetch the provider (needed once, or after changing versions.tf)
terraform fmt -check -diff      # formatting; drop -check to rewrite files
terraform validate              # syntax, types, and references
```

`terraform plan` requires real OCI credentials and a `compartment_id`, so it isn't part of the normal edit loop.

## Layout conventions

- **Files are split by concern, not by block type.** Each resource file declares its own `variable`s and `output`s next to the resources that use them. There is no `outputs.tf`, and `variables.tf` holds only `compartment_id`, which every file shares. Follow this pattern when adding resources.
  - `networks.tf`: the VCN, the Oracle Services Network data source, and the shared `locals` (protocol numbers `protocol_all`/`protocol_icmp`/`protocol_tcp`, `anywhere_cidr`, `oracle_services_network`). Use these locals rather than literal `"6"`, `"1"`, or `"0.0.0.0/0"`.
  - `gateways.tf`: internet, NAT, and service gateways.
  - `subnets.tf`: route tables, security lists, and the two subnets.
  - `flow_logs.tf`: the VCN flow log and its log group.
- Every resource is named `main` or `public`/`private`. Display names are hardcoded as `main-*` and aren't configurable.
- CIDR variables have `validation` blocks that use `can(cidrhost(...))`. New CIDR inputs should do the same.

## Networking design (spans multiple files)

- **The public subnet takes over the VCN's *default* route table and security list** through `oci_core_default_route_table` / `oci_core_default_security_list` with `manage_default_resource_id`. **The private subnet uses dedicated** `oci_core_route_table` / `oci_core_security_list` resources. Both subnets share the VCN's default DHCP options.
- Routing: public sends `0.0.0.0/0` to the internet gateway. Private sends `0.0.0.0/0` to the NAT gateway and the Oracle Services Network `SERVICE_CIDR_BLOCK` to the service gateway.
- The service gateway and the private route rule both depend on `local.oracle_services_network`, which is the first result of a regex-filtered `oci_core_services` lookup ("All .* Services In Oracle Services Network").
- **Security list philosophy** (see the comment in `subnets.tf`): a security list applies to every VNIC in the subnet, so it should only carry rules that are safe for everything in that subnet. Per-host ingress belongs in network security groups, not security lists. The public security list therefore allows only ICMP path-MTU discovery (type 3 code 4 from anywhere, type 3 from VCN CIDRs) and all egress. SSH was removed from it on purpose (commit `4a5ed4a`). The private list adds TCP/22 from VCN CIDRs only.
- VCN-internal rules loop over `var.vcn_cidr_blocks` with `dynamic` blocks, so they keep working when the VCN has multiple CIDR blocks.

## Repo notes

- Commits use Conventional Commits (`feat:`, `chore:`).
- `README.md` is the documentation for people using the module. Update its inputs, outputs, and security tables whenever variables, outputs, or security rules change. `PRD.md` and `TODO.md` hold only titles so far. `CLAUDE.md` is a symlink to this file.

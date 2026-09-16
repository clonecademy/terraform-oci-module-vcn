data "oci_core_services" "oracle_services_network" {
  filter {
    name   = "name"
    values = ["All .* Services In Oracle Services Network"]
    regex  = true
  }
}

output "oracle_services_network_cidr_block" {
  description = "Service CIDR label routed to the service gateway"
  value       = local.oracle_services_network.cidr_block
}

locals {
  protocol_all  = "all"
  protocol_icmp = "1"
  protocol_tcp  = "6"

  anywhere_cidr = "0.0.0.0/0"

  oracle_services_network = data.oci_core_services.oracle_services_network.services[0]
}

variable "vcn_cidr_blocks" {
  description = "IPv4 CIDR blocks assigned to the VCN. Subnet CIDR blocks must fall within these."
  type        = list(string)
  default     = ["10.0.0.0/16"]

  validation {
    condition     = length(var.vcn_cidr_blocks) > 0 && alltrue([for cidr in var.vcn_cidr_blocks : can(cidrhost(cidr, 0))])
    error_message = "VCN CIDR blocks must be a non-empty list of valid IPv4 CIDR notation."
  }
}

resource "oci_core_vcn" "main" {
  compartment_id = var.compartment_id
  cidr_blocks    = var.vcn_cidr_blocks
  display_name   = "main-vcn"
  dns_label      = "mainvcn"
}

output "vcn_id" {
  description = "OCID of the VCN"
  value       = oci_core_vcn.main.id
}

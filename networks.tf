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
  oracle_services_network = data.oci_core_services.oracle_services_network.services[0]
}

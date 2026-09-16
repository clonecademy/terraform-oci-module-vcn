resource "oci_core_internet_gateway" "main" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.main.id
  display_name   = "main-internet-gateway"
  enabled        = true
}

output "internet_gateway_id" {
  description = "OCID of the internet gateway used by the public subnet"
  value       = oci_core_internet_gateway.main.id
}

resource "oci_core_nat_gateway" "main" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.main.id
  display_name   = "main-nat-gateway"
  block_traffic  = false
}

output "nat_gateway_id" {
  description = "OCID of the NAT gateway used for outbound traffic from the private subnet"
  value       = oci_core_nat_gateway.main.id
}

output "nat_gateway_public_ip" {
  description = "Public IP address that private subnet traffic is translated to"
  value       = oci_core_nat_gateway.main.nat_ip
}

resource "oci_core_service_gateway" "main" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.main.id
  display_name   = "main-service-gateway"

  services {
    service_id = local.oracle_services_network.id
  }
}

output "service_gateway_id" {
  description = "OCID of the service gateway to the Oracle Services Network"
  value       = oci_core_service_gateway.main.id
}

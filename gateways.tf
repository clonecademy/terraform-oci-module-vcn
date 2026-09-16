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

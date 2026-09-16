variable "public_subnet_cidr_block" {
  description = "IPv4 CIDR block of the public subnet, which is reachable from the internet."
  type        = string
  default     = "10.0.0.0/24"

  validation {
    condition     = can(cidrhost(var.public_subnet_cidr_block, 0))
    error_message = "Public subnet CIDR block must be valid IPv4 CIDR notation, e.g. 10.0.0.0/24."
  }
}

resource "oci_core_default_route_table" "public" {
  manage_default_resource_id = oci_core_vcn.main.default_route_table_id

  route_rules {
    destination       = local.anywhere_cidr
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.main.id
  }
}

resource "oci_core_default_security_list" "public" {
  manage_default_resource_id = oci_core_vcn.main.default_security_list_id

  ingress_security_rules {
    protocol    = local.protocol_tcp
    source      = local.anywhere_cidr
    source_type = "CIDR_BLOCK"

    tcp_options {
      min = 22
      max = 22
    }
  }

  ingress_security_rules {
    protocol    = local.protocol_icmp
    source      = local.anywhere_cidr
    source_type = "CIDR_BLOCK"

    icmp_options {
      type = 3
      code = 4
    }
  }

  dynamic "ingress_security_rules" {
    for_each = toset(var.vcn_cidr_blocks)

    content {
      protocol    = local.protocol_icmp
      source      = ingress_security_rules.value
      source_type = "CIDR_BLOCK"

      icmp_options {
        type = 3
      }
    }
  }

  egress_security_rules {
    protocol         = local.protocol_all
    destination      = local.anywhere_cidr
    destination_type = "CIDR_BLOCK"
  }
}

resource "oci_core_subnet" "public" {
  compartment_id             = var.compartment_id
  vcn_id                     = oci_core_vcn.main.id
  cidr_block                 = var.public_subnet_cidr_block
  display_name               = "main-public-subnet"
  dns_label                  = "public"
  dhcp_options_id            = oci_core_vcn.main.default_dhcp_options_id
  route_table_id             = oci_core_default_route_table.public.id
  security_list_ids          = [oci_core_default_security_list.public.id]
  prohibit_public_ip_on_vnic = false
  prohibit_internet_ingress  = false
}

output "public_subnet_id" {
  description = "OCID of the public subnet"
  value       = oci_core_subnet.public.id
}

variable "private_subnet_cidr_block" {
  description = "IPv4 CIDR block of the private subnet, which reaches the internet through the NAT gateway."
  type        = string
  default     = "10.0.1.0/24"

  validation {
    condition     = can(cidrhost(var.private_subnet_cidr_block, 0))
    error_message = "Private subnet CIDR block must be valid IPv4 CIDR notation, e.g. 10.0.1.0/24."
  }
}

resource "oci_core_route_table" "private" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.main.id
  display_name   = "main-private-route-table"

  route_rules {
    destination       = local.anywhere_cidr
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_nat_gateway.main.id
  }

  route_rules {
    destination       = local.oracle_services_network.cidr_block
    destination_type  = "SERVICE_CIDR_BLOCK"
    network_entity_id = oci_core_service_gateway.main.id
  }
}

resource "oci_core_security_list" "private" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.main.id
  display_name   = "main-private-security-list"

  dynamic "ingress_security_rules" {
    for_each = toset(var.vcn_cidr_blocks)

    content {
      protocol    = local.protocol_tcp
      source      = ingress_security_rules.value
      source_type = "CIDR_BLOCK"

      tcp_options {
        min = 22
        max = 22
      }
    }
  }

  ingress_security_rules {
    protocol    = local.protocol_icmp
    source      = local.anywhere_cidr
    source_type = "CIDR_BLOCK"

    icmp_options {
      type = 3
      code = 4
    }
  }

  dynamic "ingress_security_rules" {
    for_each = toset(var.vcn_cidr_blocks)

    content {
      protocol    = local.protocol_icmp
      source      = ingress_security_rules.value
      source_type = "CIDR_BLOCK"

      icmp_options {
        type = 3
      }
    }
  }

  egress_security_rules {
    protocol         = local.protocol_all
    destination      = local.anywhere_cidr
    destination_type = "CIDR_BLOCK"
  }
}

resource "oci_core_subnet" "private" {
  compartment_id             = var.compartment_id
  vcn_id                     = oci_core_vcn.main.id
  cidr_block                 = var.private_subnet_cidr_block
  display_name               = "main-private-subnet"
  dns_label                  = "private"
  dhcp_options_id            = oci_core_vcn.main.default_dhcp_options_id
  route_table_id             = oci_core_route_table.private.id
  security_list_ids          = [oci_core_security_list.private.id]
  prohibit_public_ip_on_vnic = true
  prohibit_internet_ingress  = true
}

output "private_subnet_id" {
  description = "OCID of the private subnet"
  value       = oci_core_subnet.private.id
}

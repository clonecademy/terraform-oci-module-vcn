# The Logging service's Always Free allowance is 10 GB/month, shared across every log in the tenancy, not just this one.
# Enabling flow logs at the VCN level (rather than per-subnet) covers both subnets while creating only one log, keeping
# ingestion as low as it can be for full coverage. High-traffic VCNs can still exceed the allowance and start incurring
# cost at $0.05/GB beyond it; this module can't cap that from the outside.
resource "oci_logging_log_group" "vcn_flow_logs" {
  compartment_id = var.compartment_id
  display_name   = "main-vcn-flow-logs"
}

variable "vcn_flow_logs_retention_in_days" {
  description = "Retention period for VCN flow logs. OCI Logging only accepts 30-day increments up to 180."
  type        = number
  default     = 30

  validation {
    condition     = contains([30, 60, 90, 120, 150, 180], var.vcn_flow_logs_retention_in_days)
    error_message = "VCN flow log retention must be one of 30, 60, 90, 120, 150, or 180 days."
  }
}

resource "oci_logging_log" "vcn_flow_logs" {
  display_name = "main-vcn-flow-log"
  log_group_id = oci_logging_log_group.vcn_flow_logs.id
  log_type     = "SERVICE"

  configuration {
    compartment_id = var.compartment_id

    source {
      category    = "all"
      resource    = oci_core_vcn.main.id
      service     = "flowlogs"
      source_type = "OCISERVICE"
    }
  }

  is_enabled         = true
  retention_duration = var.vcn_flow_logs_retention_in_days
}

output "vcn_flow_log_group_id" {
  description = "OCID of the log group containing the VCN flow log"
  value       = oci_logging_log_group.vcn_flow_logs.id
}

output "vcn_flow_log_id" {
  description = "OCID of the VCN flow log"
  value       = oci_logging_log.vcn_flow_logs.id
}

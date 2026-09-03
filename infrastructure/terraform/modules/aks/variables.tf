variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "prefix" { type = string }
variable "subnet_id" { type = string }
variable "node_count" { type = number }
variable "node_vm_size" { type = string }
variable "pod_cidr" { type = string }
variable "service_cidr" { type = string }
variable "dns_service_ip" { type = string }
variable "tags" { type = map(string) }

variable "admin_group_object_ids" {
  description = "Microsoft Entra group object IDs allowed to administer the AKS cluster. Required because local accounts are disabled."
  type        = list(string)
  validation {
    condition     = length(var.admin_group_object_ids) > 0 && alltrue([for id in var.admin_group_object_ids : can(regex("^[0-9a-fA-F-]{36}$", id))])
    error_message = "Provide at least one valid Microsoft Entra group object ID for AKS administration."
  }
}

variable "api_server_authorized_ip_ranges" {
  description = "Optional CIDRs allowed to reach the public AKS API server. Leave empty only when the training connectivity design explicitly requires it."
  type        = list(string)
  default     = []
}

variable "sku_tier" {
  description = "AKS control plane tier. Free is sufficient for a short-lived training lab; Standard can be selected for stronger SLA characteristics."
  type        = string
  default     = "Free"
  validation {
    condition     = contains(["Free", "Standard", "Premium"], var.sku_tier)
    error_message = "AKS sku_tier must be Free, Standard, or Premium."
  }
}

variable "private_cluster_enabled" {
  description = "Whether the AKS API server is private. Prefer true when XDevOps/trainer network connectivity supports it."
  type        = bool
  default     = false
}

variable "allow_public_api_without_authorized_ip_ranges" {
  description = "Explicit training-only override allowing a public AKS API without an authorized CIDR allowlist."
  type        = bool
  default     = false
}

variable "subscription_id" {
  description = "Azure subscription ID used for the dedicated training environment."
  type        = string
}

variable "prefix" {
  description = "Short lowercase naming prefix for public training resources, e.g. xdevops-demo."
  type        = string
  default     = "xdevops-demo"
}

variable "location" {
  type    = string
  default = "westeurope"
}


variable "expires_on" {
  description = "Required training environment expiry date (YYYY-MM-DD) for cost/governance tracking."
  type        = string
  validation {
    condition     = can(regex("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", var.expires_on))
    error_message = "expires_on must use YYYY-MM-DD format."
  }
}

variable "vnet_cidr" {
  type    = string
  default = "10.42.0.0/16"
}

variable "aks_subnet_cidr" {
  type    = string
  default = "10.42.0.0/22"
}

variable "postgres_subnet_cidr" {
  type    = string
  default = "10.42.4.0/24"
}

variable "pod_cidr" {
  type    = string
  default = "10.244.0.0/16"
}

variable "service_cidr" {
  type    = string
  default = "10.43.0.0/16"
}

variable "dns_service_ip" {
  type    = string
  default = "10.43.0.10"
}

variable "aks_node_count" {
  type    = number
  default = 2
}

variable "aks_node_vm_size" {
  type    = string
  default = "Standard_D4s_v5"
}

variable "postgres_administrator_login" {
  type    = string
  default = "xdevopstraining"
}

variable "postgres_database_name" {
  type    = string
  default = "training"
}

variable "postgres_sku_name" {
  type    = string
  default = "B_Standard_B1ms"
}

variable "postgres_storage_mb" {
  type    = number
  default = 32768
}

variable "postgres_version" {
  type    = string
  default = "16"
}

variable "extra_tags" {
  type    = map(string)
  default = {}
}

variable "aks_admin_group_object_ids" {
  description = "Microsoft Entra group object IDs that administer AKS. Local Kubernetes accounts are disabled."
  type        = list(string)
  validation {
    condition     = length(var.aks_admin_group_object_ids) > 0
    error_message = "Set aks_admin_group_object_ids to at least one Microsoft Entra group object ID."
  }
}

variable "aks_api_server_authorized_ip_ranges" {
  description = "Optional CIDRs allowed to reach the AKS public API server. Explicitly decide this for the training deployment."
  type        = list(string)
  default     = []
}


variable "aks_private_cluster_enabled" {
  description = "Use a private AKS API server when the XDevOps/trainer network path supports it."
  type        = bool
  default     = false
}

variable "allow_public_api_without_authorized_ip_ranges" {
  description = "Explicit break-glass training override. Keep false for public/enterprise use. When false, a public AKS API requires at least one authorized CIDR."
  type        = bool
  default     = false
}

variable "aks_sku_tier" {
  description = "AKS control-plane tier. Standard is the enterprise-course baseline for control-plane SLA/reliability; Free can be chosen for local rehearsal."
  type        = string
  default     = "Standard"
}

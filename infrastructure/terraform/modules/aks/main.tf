resource "azurerm_kubernetes_cluster" "this" {
  name                = "aks-${var.prefix}-training"
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = "aks-${var.prefix}-training"
  sku_tier            = var.sku_tier

  role_based_access_control_enabled = true
  local_account_disabled            = true
  private_cluster_enabled            = var.private_cluster_enabled
  oidc_issuer_enabled               = true
  workload_identity_enabled         = true
  azure_policy_enabled              = true

  azure_active_directory_role_based_access_control {
    admin_group_object_ids = var.admin_group_object_ids
    azure_rbac_enabled     = true
  }

  default_node_pool {
    name                 = "system"
    vm_size              = var.node_vm_size
    node_count           = var.node_count
    vnet_subnet_id       = var.subnet_id
    auto_scaling_enabled = false
    max_pods             = 110
    os_disk_size_gb      = 64
    type                 = "VirtualMachineScaleSets"

    upgrade_settings {
      max_surge = "33%"
    }
  }

  identity {
    type = "SystemAssigned"
  }

  dynamic "api_server_access_profile" {
    for_each = length(var.api_server_authorized_ip_ranges) > 0 ? [1] : []
    content {
      authorized_ip_ranges = var.api_server_authorized_ip_ranges
    }
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_policy      = "cilium"
    network_data_plane  = "cilium"
    outbound_type       = "loadBalancer"
    pod_cidr            = var.pod_cidr
    service_cidr        = var.service_cidr
    dns_service_ip      = var.dns_service_ip
  }

  lifecycle {
    precondition {
      condition     = !(var.private_cluster_enabled && length(var.api_server_authorized_ip_ranges) > 0)
      error_message = "AKS private cluster mode and API authorized IP ranges are mutually exclusive in this training module."
    }
    precondition {
      condition     = var.private_cluster_enabled || length(var.api_server_authorized_ip_ranges) > 0 || var.allow_public_api_without_authorized_ip_ranges
      error_message = "Public AKS API access requires at least one authorized CIDR. Prefer private_cluster_enabled=true, or set authorized CIDRs. The explicit override is for isolated rehearsal only."
    }
  }

  tags = var.tags
}

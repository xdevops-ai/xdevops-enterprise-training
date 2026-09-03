locals {
  tags = merge({
    workload    = "xdevops-enterprise-training"
    environment = "training"
    managed_by  = "terraform"
    owner        = "xdevops"
    expires_on   = var.expires_on
  }, var.extra_tags)
}

resource "azurerm_resource_group" "training" {
  name     = "rg-${var.prefix}-training"
  location = var.location
  tags     = local.tags
}

module "network" {
  source = "../../modules/network"

  resource_group_name  = azurerm_resource_group.training.name
  location             = azurerm_resource_group.training.location
  prefix               = var.prefix
  vnet_cidr            = var.vnet_cidr
  aks_subnet_cidr      = var.aks_subnet_cidr
  postgres_subnet_cidr = var.postgres_subnet_cidr
  tags                 = local.tags
}

module "aks" {
  source = "../../modules/aks"

  resource_group_name                              = azurerm_resource_group.training.name
  location                                         = azurerm_resource_group.training.location
  prefix                                           = var.prefix
  subnet_id                                        = module.network.aks_subnet_id
  node_count                                       = var.aks_node_count
  node_vm_size                                     = var.aks_node_vm_size
  pod_cidr                                         = var.pod_cidr
  service_cidr                                     = var.service_cidr
  dns_service_ip                                   = var.dns_service_ip
  admin_group_object_ids                           = var.aks_admin_group_object_ids
  api_server_authorized_ip_ranges                  = var.aks_api_server_authorized_ip_ranges
  private_cluster_enabled                          = var.aks_private_cluster_enabled
  allow_public_api_without_authorized_ip_ranges    = var.allow_public_api_without_authorized_ip_ranges
  sku_tier                                         = var.aks_sku_tier
  tags                                             = local.tags
}

module "postgres" {
  source = "../../modules/postgres"

  resource_group_name = azurerm_resource_group.training.name
  location            = azurerm_resource_group.training.location
  prefix              = var.prefix
  delegated_subnet_id = module.network.postgres_subnet_id
  vnet_id             = module.network.vnet_id
  administrator_login = var.postgres_administrator_login
  database_name       = var.postgres_database_name
  sku_name            = var.postgres_sku_name
  storage_mb          = var.postgres_storage_mb
  postgres_version    = var.postgres_version
  tags                = local.tags
}

module "acr" {
  source = "../../modules/acr"

  resource_group_name = azurerm_resource_group.training.name
  location            = azurerm_resource_group.training.location
  prefix              = var.prefix
  tags                = local.tags
}

resource "azurerm_role_assignment" "aks_acr_pull" {
  scope                = module.acr.id
  role_definition_name = "AcrPull"
  principal_id         = module.aks.kubelet_identity_object_id
}

resource "azurerm_role_assignment" "aks_admin_rbac" {
  for_each = toset(var.aks_admin_group_object_ids)

  scope                = module.aks.id
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  principal_id         = each.value
}

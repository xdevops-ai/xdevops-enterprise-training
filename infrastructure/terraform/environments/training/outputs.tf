output "resource_group_name" { value = azurerm_resource_group.training.name }
output "location" { value = azurerm_resource_group.training.location }
output "aks_name" { value = module.aks.name }
output "aks_id" { value = module.aks.id }
output "aks_admin_group_object_ids" { value = var.aks_admin_group_object_ids }
output "acr_name" { value = module.acr.name }
output "acr_login_server" { value = module.acr.login_server }
output "vnet_name" { value = module.network.vnet_name }
output "aks_subnet_name" { value = module.network.aks_subnet_name }
output "postgres_subnet_name" { value = module.network.postgres_subnet_name }
output "postgres_nsg_name" { value = module.network.postgres_nsg_name }
output "postgres_nsg_rule_name" { value = module.network.postgres_rule_name }
output "postgres_server_name" { value = module.postgres.name }
output "postgres_fqdn" { value = module.postgres.fqdn }
output "postgres_database_names" { value = module.postgres.database_names }
output "postgres_administrator_login" { value = module.postgres.administrator_login }
output "postgres_administrator_password" {
  value     = module.postgres.administrator_password
  sensitive = true
}
output "postgres_application_logins" { value = module.postgres.application_logins }
output "postgres_application_passwords" {
  value     = module.postgres.application_passwords
  sensitive = true
}
output "postgres_subnet_cidr" { value = var.postgres_subnet_cidr }

output "name" { value = azurerm_postgresql_flexible_server.this.name }
output "id" { value = azurerm_postgresql_flexible_server.this.id }
output "fqdn" { value = azurerm_postgresql_flexible_server.this.fqdn }
output "database_names" {
  value = { for env, db in azurerm_postgresql_flexible_server_database.training : env => db.name }
}
output "administrator_login" { value = azurerm_postgresql_flexible_server.this.administrator_login }
output "administrator_password" {
  value     = random_password.admin.result
  sensitive = true
}
output "application_logins" { value = local.application_logins }
output "application_passwords" {
  value     = { for env, password in random_password.app : env => password.result }
  sensitive = true
}

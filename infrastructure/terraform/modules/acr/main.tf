resource "random_string" "suffix" {
  length  = 5
  upper   = false
  special = false
}

locals {
  normalized_prefix = replace(lower(var.prefix), "-", "")
}

resource "azurerm_container_registry" "this" {
  name                = "acr${local.normalized_prefix}${random_string.suffix.result}"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "Basic"
  admin_enabled       = false
  tags                = var.tags
}

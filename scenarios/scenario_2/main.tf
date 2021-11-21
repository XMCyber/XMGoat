#############################################################################
# VARIABLES
#############################################################################
variable "user_name" {
  type        = string
}

variable "key_vault_name" {
  type        = string
}

variable "resource_group" {
  type        = string
  description = "Existing resource group to deploy resources"
}

variable "domain" {
  type        = string
  description = "Domain name (for example: contoso.onmicrosoft.com)"
}

variable "user_password" {
  type    = string
}

#############################################################################
# DATA
#############################################################################
data "azurerm_client_config" "current" {}

data "azurerm_subscription" "current" {}

data "azurerm_resource_group" "current" {
  name = var.resource_group
}


#############################################################################
# PROVIDERS
#############################################################################

provider "azurerm" {
  features {}
}

provider "azuread" {
}


#############################################################################
# RESOURCES
#############################################################################

## AZURE AD USER ##

resource "azuread_user" "user" {
  user_principal_name = "${var.user_name}@${var.domain}"
  display_name        = var.user_name
  password            = var.user_password
}

resource "azuread_application" "scenario2App" {
  display_name = "scenario2App"
}

resource "azuread_service_principal" "scenario2SPN" {
  application_id               = azuread_application.scenario2App.application_id
}

resource "azuread_application_password" "secret" {
  application_object_id = azuread_application.scenario2App.object_id
}

## AZURE KEY VAULT Secret ##

resource "azurerm_key_vault" "main" {
  name                        = var.key_vault_name
  location                    = data.azurerm_resource_group.current.location
  resource_group_name         = data.azurerm_resource_group.current.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  purge_protection_enabled    = false
  sku_name = "standard"

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id
    key_permissions = [
      "get",
    ]
    secret_permissions = [
      "get", "backup", "delete", "list", "purge", "recover", "restore", "set",
    ]
    storage_permissions = [
      "get",
    ]
  }

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = azuread_service_principal.scenario2SPN.object_id
    key_permissions = [
      "get",
    ]
    secret_permissions = [
      "get", "backup", "delete", "list", "purge", "recover", "restore", "set",
    ]
    storage_permissions = [
      "get",
    ]
  }
}

resource "azurerm_key_vault_secret" "secret" {
  name         = azuread_user.user.display_name
  value        = azuread_user.user.password
  key_vault_id = azurerm_key_vault.main.id
  depends_on = [azurerm_key_vault.main]
}

## AZURE ROLES AND ROLE ASSIGNMENT ##

resource "azurerm_role_definition" "list-key-vaults" {
  name     = "Key-Vault Read Scenario 2"
  scope    = data.azurerm_subscription.current.id
  description = "This role allow to list key vaults"

  permissions {
    actions     = ["Microsoft.KeyVault/vaults/read"]
  }

  assignable_scopes = [
    data.azurerm_subscription.current.id,
  ]
}

resource "azurerm_role_definition" "assign_privileges" {
  name     = "Add Myself Privileges Scenario 2"
  scope    = data.azurerm_subscription.current.id
  description = "This role allow escalate our privileges"

  permissions {
    actions     = ["Microsoft.Authorization/roleAssignments/write"]
  }

  assignable_scopes = [
    data.azurerm_subscription.current.id,
  ]
}

resource "azurerm_role_assignment" "key-vault-assignment-for-spn" {
  scope              = azurerm_key_vault.main.id
  role_definition_id = split("|", azurerm_role_definition.list-key-vaults.id)[0]
  principal_id       = azuread_service_principal.scenario2SPN.object_id
}

resource "azurerm_role_assignment" "escalate-privileges" {
  scope              = data.azurerm_subscription.current.id
  role_definition_id = split("|", azurerm_role_definition.assign_privileges.id)[0]
  principal_id       = azuread_user.user.id
}

## Output
output "application_id"{
  value = azuread_application.scenario2App.application_id
}
output "application_secret" {
  value = azuread_application_password.secret
  sensitive = true
}

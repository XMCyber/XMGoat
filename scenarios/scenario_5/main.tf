#############################################################################
# VARIABLES
#############################################################################
variable "user_name" {
  type        = string
  default     = "us5"
}

variable "resource_group" {
  type        = string
  description = "Existing resource group to deploy resources"
  default     = "sc5"
}

variable "key_vault_name" {
  type        = string
  description = "key vault name"
  default     = "kv5zur555"
}

variable "domain" {
  type        = string
  description = "Domain name (for example: contoso.onmicrosoft.com)"
  default     = "xmazuretestgmail.onmicrosoft.com"
}

variable "user_password" {
  type    = string
  default     = "Hahahaha147222343!"
}

variable "user_assigned_identity_name" {
  type        = string
  default     = "id5"
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

resource "azuread_application" "scenario5App" {
  display_name = "scenario5App"
  owners = [azuread_user.user.object_id]
  }

resource "azuread_service_principal" "scenario5SPN" {
  application_id               = azuread_application.scenario5App.application_id
  owners                       = [azuread_user.user.object_id]
}

## AZURE APP FUNCTION ##

resource "azurerm_storage_account" "sensitiveSA" {
  name                     = "xmgoat5"
  resource_group_name      = data.azurerm_resource_group.current.name
  location                 = data.azurerm_resource_group.current.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "sensitiveCont" {
  name = "sensitive-data"
  storage_account_name = azurerm_storage_account.sensitiveSA.name
  container_access_type = "blob"
}

resource "azurerm_storage_blob" "sensitiveZIP" {
  name                   = "SensitiveData.zip"
  storage_account_name   = azurerm_storage_account.sensitiveSA.name
  storage_container_name = azurerm_storage_container.sensitiveCont.name
  type                   = "Block"
  source                 = "./SensitiveData.zip"
}

resource "azurerm_service_plan" "main" {
  name                = "xmgoat5"
  resource_group_name = data.azurerm_resource_group.current.name
  location            = data.azurerm_resource_group.current.location
  os_type             = "Windows"
  sku_name            = "Y1"
}


resource "azurerm_user_assigned_identity" "app-identity" {
  name                = var.user_assigned_identity_name
  resource_group_name = data.azurerm_resource_group.current.name
  location            = data.azurerm_resource_group.current.location
}

resource "azurerm_windows_function_app" "main" {
  name                = "sc5-windows-function-app"
  resource_group_name = data.azurerm_resource_group.current.name
  location            = data.azurerm_resource_group.current.location

  storage_account_name       = azurerm_storage_account.sensitiveSA.name
  storage_account_access_key = azurerm_storage_account.sensitiveSA.primary_access_key
  service_plan_id            = azurerm_service_plan.main.id

  site_config {}

  identity {
      type         = "SystemAssigned, UserAssigned"
      identity_ids = [azurerm_user_assigned_identity.app-identity.id]
    }
}

resource "azurerm_key_vault" "secrets-key-vault" {
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
        "Get",
      ]
      secret_permissions = [
        "Get", "Backup", "Delete", "List", "Purge", "Recover", "Restore", "Set",
      ]
      storage_permissions = [
        "Get",
      ]
    }

  access_policy {
      tenant_id = data.azurerm_client_config.current.tenant_id
      object_id = azurerm_user_assigned_identity.app-identity.principal_id
      key_permissions = [
        "Get",
      ]
      secret_permissions = [
        "Get", "Backup", "Delete", "List", "Purge", "Recover", "Restore", "Set",
      ]
      storage_permissions = [
        "Get",
      ]
    }
}

resource "azurerm_key_vault_secret" "secret" {
  name         = "ZIP-Password"
  value        = "Hahahaha147222343!"
  key_vault_id = azurerm_key_vault.secrets-key-vault.id
  depends_on = [azurerm_key_vault.secrets-key-vault]
}

## AZURE ROLE AND ROLE ASSIGNMENT ##

resource "azurerm_role_definition" "public-xml-scm-service-1" {
  name     = "Publish XML SCM service-1"
  scope    = data.azurerm_subscription.current.id
  description = "This role allow to update function code"

  permissions {
      actions     = ["microsoft.web/publishingusers/write", "Microsoft.Web/sites/publishxml/Action", "Microsoft.Web/sites/basicPublishingCredentialsPolicies/Write", "Microsoft.Web/sites/publish/Action", "Microsoft.Authorization/roleAssignments/read", "Microsoft.Authorization/roleDefinitions/read", "Microsoft.Web/sites/Read", "Microsoft.ManagedIdentity/userAssignedIdentities/read"]
      not_actions = []
    }

  assignable_scopes = [
    data.azurerm_subscription.current.id,
  ]
}

resource "azurerm_role_definition" "custom-identity-reader-sc5-11" {
  name     = "Custom Identity reader sc5-11"
  scope    = data.azurerm_subscription.current.id
  description = "This role allow to recon identities"

  permissions {
    actions     = ["Microsoft.ManagedIdentity/identities/read", "Microsoft.ManagedIdentity/userAssignedIdentities/read"]
    not_actions = []
  }

  assignable_scopes = [
    data.azurerm_subscription.current.id,
  ]
}

resource "azurerm_role_definition" "encrypt-decrypt-storage-account-role-111" {
  name     = "Encrypt and Decrypt storage account role-111"
  scope    = data.azurerm_subscription.current.id
  description = "This role allow to update function code"

  permissions {
      actions     = ["Microsoft.Storage/storageAccounts/read", "Microsoft.Storage/storageAccounts/blobServices/containers/read", "Microsoft.Authorization/roleAssignments/read", "Microsoft.Authorization/roleDefinitions/read", "Microsoft.Storage/storageAccounts/listAccountSas/action"]
      data_actions = ["Microsoft.Storage/storageAccounts/blobServices/containers/blobs/read"]
      not_actions = []
    }

  assignable_scopes = [
    data.azurerm_subscription.current.id,
  ]
}

resource "azurerm_role_assignment" "public-xml-scm-service-assignment" {
  scope              = azurerm_windows_function_app.main.id
  role_definition_id = split("|", azurerm_role_definition.public-xml-scm-service-1.id)[0]
  principal_id       = azuread_service_principal.scenario5SPN.id
}

resource "azurerm_role_assignment" "custom-identity-reader-sc5" {
  scope              =  data.azurerm_subscription.current.id
  role_definition_id = split("|", azurerm_role_definition.custom-identity-reader-sc5-11.id)[0]
  principal_id       = azuread_service_principal.scenario5SPN.id
}

resource "azurerm_role_assignment" "encrypt-decrypt-storage-account-assignment" {
  scope              = azurerm_storage_account.sensitiveSA.id
  role_definition_id = split("|", azurerm_role_definition.encrypt-decrypt-storage-account-role-111.id)[0]
  principal_id       = azurerm_user_assigned_identity.app-identity.principal_id
}


## Output
output "username"{
  value = azuread_user.user.user_principal_name
}
output "password" {
  value = azuread_user.user.password
  sensitive = true
}

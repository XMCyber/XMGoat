#############################################################################
# VARIABLES
#############################################################################
variable "user_name" {
  type        = string
  default     = "us4"
}

variable "resource_group" {
  type        = string
  description = "Existing resource group to deploy resources"
  default     = "sc4"
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
  default     = "id4"
}

#############################################################################
# DATA
#############################################################################
data "azurerm_client_config" "current" {}

data "azurerm_subscription" "current" {}

data "azurerm_resource_group" "current" {
  name = var.resource_group
}

data "azuread_application_published_app_ids" "well_known" {}


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

resource "azuread_service_principal" "msgraph" {
  application_id = data.azuread_application_published_app_ids.well_known.result.MicrosoftGraph
  use_existing   = true
}

resource "azuread_application" "scenario4App" {
  display_name = "scenario4App"

  required_resource_access {
    resource_app_id = data.azuread_application_published_app_ids.well_known.result.MicrosoftGraph

    resource_access {
      id   = azuread_service_principal.msgraph.app_role_ids["RoleManagement.ReadWrite.Directory"]
      type = "Role"
    }

    resource_access {
      id   = azuread_service_principal.msgraph.oauth2_permission_scope_ids["RoleManagement.ReadWrite.Directory"]
      type = "Scope"
    }
  }
}


resource "azuread_service_principal" "scenario4SPN" {
  application_id               = azuread_application.scenario4App.application_id
}

## AZURE APP FUNCTION ##

resource "azurerm_storage_account" "main" {
  name                     = "xmgoat4"
  resource_group_name      = data.azurerm_resource_group.current.name
  location                 = data.azurerm_resource_group.current.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "main" {
  name = "function-releases"
  storage_account_name = azurerm_storage_account.main.name
  container_access_type = "private"
}

resource "azurerm_service_plan" "main" {
  name                = "xmgoat4"
  resource_group_name = data.azurerm_resource_group.current.name
  location            = data.azurerm_resource_group.current.location
  os_type             = "Windows"
  sku_name            = "Y1"
}


resource "azurerm_user_assigned_identity" "main" {
  name                = var.user_assigned_identity_name
  resource_group_name = data.azurerm_resource_group.current.name
  location            = data.azurerm_resource_group.current.location
}

resource "azurerm_windows_function_app" "main" {
  name                = "sc4-windows-function-app"
  resource_group_name = data.azurerm_resource_group.current.name
  location            = data.azurerm_resource_group.current.location

  storage_account_name       = azurerm_storage_account.main.name
  storage_account_access_key = azurerm_storage_account.main.primary_access_key
  service_plan_id            = azurerm_service_plan.main.id

  site_config {}

  identity {
      type         = "SystemAssigned, UserAssigned"
      identity_ids = [azurerm_user_assigned_identity.main.id]
    }
}

## AZURE ROLE AND ROLE ASSIGNMENT ##

resource "azurerm_role_definition" "generate-jwt-token-to-scm-1" {
  name     = "Generate JWT Token to SCM-1"
  scope    = data.azurerm_subscription.current.id
  description = "This role allow to update function code"

  permissions {
    actions     = ["Microsoft.web/sites/Read", "Microsoft.Web/sites/publish/Action", "Microsoft.Authorization/roleAssignments/read", "Microsoft.Authorization/roleDefinitions/read","Microsoft.ManagedIdentity/identities/read", "Microsoft.ManagedIdentity/userAssignedIdentities/read"]
    not_actions = []
  }

  assignable_scopes = [
    data.azurerm_subscription.current.id,
  ]
}

resource "azurerm_role_definition" "custom-identity-reader" {
  name     = "Custom Identity reader"
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

resource "azurerm_role_assignment" "generate-jwt-token-to-scm-1" {
  scope              = azurerm_windows_function_app.main.id
  role_definition_id = split("|", azurerm_role_definition.generate-jwt-token-to-scm-1.id)[0]
  principal_id       = azuread_user.user.id
}

resource "azurerm_role_assignment" "custom-identity-reader" {
  scope              =  data.azurerm_subscription.current.id
  role_definition_id = split("|", azurerm_role_definition.custom-identity-reader.id)[0]
  principal_id       = azuread_user.user.id
}

## Directory Roles
resource "azuread_directory_role" "appAdmin" {
  display_name = "Application administrator"
}

resource "azuread_directory_role_member" "appAdminMembers" {
  role_object_id   = azuread_directory_role.appAdmin.object_id
  member_object_id = azurerm_user_assigned_identity.main.principal_id
}

resource "azuread_app_role_assignment" "ADRoleManagementRole" {
  app_role_id         = azuread_service_principal.msgraph.app_role_ids["RoleManagement.ReadWrite.Directory"]
  principal_object_id = azuread_service_principal.scenario4SPN.object_id
  resource_object_id  = azuread_service_principal.msgraph.object_id
}

## Output
output "username"{
  value = azuread_user.user.user_principal_name
}
output "password" {
  value = azuread_user.user.password
  sensitive = true
}

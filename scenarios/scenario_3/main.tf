#############################################################################
# VARIABLES
#############################################################################
variable "user_name" {
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

variable "user_assigned_identity_name" {
  type        = string
}

#############################################################################
# DATA
#############################################################################
data "azurerm_client_config" "current" {}

data "azurerm_subscription" "current" {}

data "azurerm_resource_group" "current" {
  name = var.resource_group
}

data "archive_file" "file_function_app" {
  type        = "zip"
  source_dir  = "xmgoat3-function-project"
  output_path = "function-app.zip"
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

resource "azuread_application" "scenario3App" {
  display_name = "scenario3App"
}

resource "azuread_service_principal" "scenario3SPN" {
  application_id               = azuread_application.scenario3App.application_id
}

## AZURE APP FUNCTION ##

resource "azurerm_storage_account" "main" {
  name                     = "xmgoat3"
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

resource "azurerm_application_insights" "main" {
  name                = "xmgoat3"
  location            = data.azurerm_resource_group.current.location
  resource_group_name = data.azurerm_resource_group.current.name
  application_type    = "Node.JS"
}

resource "azurerm_app_service_plan" "main" {
  name                = "xmgoat3"
  location            = data.azurerm_resource_group.current.location
  resource_group_name = data.azurerm_resource_group.current.name
  kind                = "FunctionApp"
  reserved = false

  sku {
    tier = "Dynamic"
    size = "Y1"
  }
}

resource "azurerm_user_assigned_identity" "main" {
  name                = var.user_assigned_identity_name
  resource_group_name = data.azurerm_resource_group.current.name
  location            = data.azurerm_resource_group.current.location
}

resource "azurerm_function_app" "main" {
  name                       = "xmgoat3"
  location                   = data.azurerm_resource_group.current.location
  resource_group_name        = data.azurerm_resource_group.current.name
  app_service_plan_id        = azurerm_app_service_plan.main.id
  storage_account_name       = azurerm_storage_account.main.name
  storage_account_access_key = azurerm_storage_account.main.primary_access_key
  
  app_settings = {
    "FUNCTIONS_WORKER_RUNTIME" = "powershell",
	AzureWebJobsStorage = azurerm_storage_account.main.primary_blob_connection_string,
	APPINSIGHTS_INSTRUMENTATIONKEY = azurerm_application_insights.main.instrumentation_key,
	"WEBSITE_NODE_DEFAULT_VERSION" = "~14"
  }
  
  version                    = "~3"

  identity {
    type         = "SystemAssigned, UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.main.id]
  }

  lifecycle {
    ignore_changes = [
      app_settings["WEBSITE_RUN_FROM_PACKAGE"]
    ]
  }
  
  site_config {
    cors {
      allowed_origins = ["*"]
    }
	use_32_bit_worker_process = false
  }
}

## AZURE ROLE AND ROLE ASSIGNMENT ##

resource "azurerm_role_definition" "update-function-code" {
  name     = "Update Function Code Scenario 3"
  scope    = data.azurerm_subscription.current.id
  description = "This role allow to update function code"

  permissions {
    actions     = ["Microsoft.web/sites/Read", "microsoft.web/sites/functions/read", "microsoft.web/sites/host/listkeys/action"]
    not_actions = []
  }

  assignable_scopes = [
    data.azurerm_subscription.current.id,
  ]
}

resource "azurerm_role_assignment" "update-function-code" {
  scope              = azurerm_function_app.main.id
  role_definition_id = split("|", azurerm_role_definition.update-function-code.id)[0]
  principal_id       = azuread_user.user.id
}

## Directory Roles
resource "azuread_directory_role" "appAdmin" {
  display_name = "Application administrator"
}

resource "azuread_directory_role" "globalAdmin" {
  display_name = "Global administrator"
}

resource "azuread_directory_role_member" "appAdminMembers" {
  role_object_id   = azuread_directory_role.appAdmin.object_id
  member_object_id = azurerm_user_assigned_identity.main.principal_id
}

resource "azuread_directory_role_member" "globalAdminMembers" {
  role_object_id   = azuread_directory_role.globalAdmin.object_id
  member_object_id = azuread_service_principal.scenario3SPN.object_id
}

locals {
    publish_code_command = "az webapp deploy --resource-group ${data.azurerm_resource_group.current.name} --name ${azurerm_function_app.main.name} --src-path ${data.archive_file.file_function_app.output_path}"
}

resource "null_resource" "function_app_publish" {
  provisioner "local-exec" {
    command = local.publish_code_command
  }
  depends_on = [local.publish_code_command]
  triggers = {
    input_json = filemd5(data.archive_file.file_function_app.output_path)
    publish_code_command = local.publish_code_command
  }
}


## Output
output "username"{
  value = azuread_user.user.user_principal_name
}
output "password" {
  value = azuread_user.user.password
  sensitive = true
}

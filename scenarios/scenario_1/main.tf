#############################################################################
# VARIABLES
#############################################################################
variable "container_name" {
  type        = string
}

variable "storage_account_name" {
  type        = string
}

variable "linux_virtual_machine_name" {
  type        = string
}

variable "virtual_network_name" {
  type        = string
}

variable "user_name" {
  type        = string
}

variable "user_assigned_identity_name" {
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

variable "vm_password" {
  type    = string
}

variable "vm_user" {
  type    = string
}

#############################################################################
# DATA
#############################################################################

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

resource "azuread_application" "scenario1App" {
  display_name = "scenario1App"
  owners = [azuread_user.user.object_id]
}

resource "azuread_service_principal" "scenario1SPN" {
  application_id               = azuread_application.scenario1App.application_id
  owners                       = [azuread_user.user.id]
}


## AZURE LINUX VIRTUAL MACHINE ##

resource "azurerm_virtual_network" "main" {
  name                = var.virtual_network_name
  address_space       = ["10.0.0.0/16"]
  location            =  data.azurerm_resource_group.current.location
  resource_group_name = data.azurerm_resource_group.current.name
}

resource "azurerm_subnet" "internal" {
  name                 = "internal"
  resource_group_name  = data.azurerm_resource_group.current.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.2.0/24"]
}


resource "azurerm_user_assigned_identity" "uai" {
  name                = var.user_assigned_identity_name
  resource_group_name = data.azurerm_resource_group.current.name
  location            = data.azurerm_resource_group.current.location
}

resource "azurerm_network_interface" "linux" {
  name                = var.linux_virtual_machine_name
  resource_group_name = data.azurerm_resource_group.current.name
  location            = data.azurerm_resource_group.current.location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "main" {
  name                            = var.linux_virtual_machine_name
  resource_group_name             = data.azurerm_resource_group.current.name
  location                        = data.azurerm_resource_group.current.location
  size                            = "Standard_B2s"
  admin_username                  = var.vm_user
  admin_password                  = var.vm_password
  disable_password_authentication = false
  network_interface_ids = [
    azurerm_network_interface.linux.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

  identity {
    type         = "SystemAssigned, UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.uai.id]
  }
}

## AZURE STORAGE ACCOUNT ##
resource "azurerm_storage_account" "main" {
  name                     = var.storage_account_name
  resource_group_name      = data.azurerm_resource_group.current.name
  location                 = data.azurerm_resource_group.current.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "main" {
  name                  = var.container_name
  storage_account_name  = azurerm_storage_account.main.name
  container_access_type = "private"
}

resource "azurerm_storage_blob" "file" {
  name                   = "secret.txt"
  storage_account_name   = azurerm_storage_account.main.name
  storage_container_name = azurerm_storage_container.main.name
  type                   = "Block"
  source                 = "secret.txt"
}


## AZURE ROLE AND ROLE ASSIGNMENT ##

resource "azurerm_role_definition" "run-command-on-vm" {
  name     = "Run Command Role Scenario 1"
  scope    = data.azurerm_subscription.current.id
  description = "This role allow to run command on vm"

  permissions {
    actions     = ["Microsoft.Compute/virtualMachines/read", "Microsoft.Compute/virtualMachines/runCommand/action"]
    not_actions = []
  }

  assignable_scopes = [
    data.azurerm_subscription.current.id,
  ]
}

resource "azurerm_role_assignment" "run-command-on-linux-vm" {
  scope              = azurerm_linux_virtual_machine.main.id
  role_definition_id = split("|", azurerm_role_definition.run-command-on-vm.id)[0]
  principal_id       = azuread_service_principal.scenario1SPN.id
}

resource "azurerm_role_definition" "read-blobs" {
  name     = "Read Blobs Role Scenario 1"
  scope    = data.azurerm_subscription.current.id
  description = "This role allow to download blobs from storage account"

  permissions {
    actions     = ["Microsoft.Storage/storageAccounts/read", "Microsoft.Storage/storageAccounts/blobServices/containers/read"]
    data_actions = ["Microsoft.Storage/storageAccounts/blobServices/containers/blobs/read"]
    not_actions = []
  }

  assignable_scopes = [
    data.azurerm_subscription.current.id,
  ]
}

resource "azurerm_role_assignment" "read-blobs" {
  scope              = azurerm_storage_account.main.id
  role_definition_id = split("|", azurerm_role_definition.read-blobs.id)[0]
  principal_id       = azurerm_user_assigned_identity.uai.principal_id
}

## Output
output "username"{
  value = azuread_user.user.user_principal_name
}
output "password" {
  value = azuread_user.user.password
  sensitive = true
}

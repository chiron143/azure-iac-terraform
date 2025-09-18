terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = "rg-azure-iac-terraform-test"
  location = "East US"

  tags = {
    Environment = "Test"
    Project     = "Azure-IAC-Terraform"
    ManagedBy   = "Terraform"
  }
}

# Virtual Network
resource "azurerm_virtual_network" "main" {
  name                = "vnet-secure-webapp"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  tags = {
    Environment = "Test"
    Project     = "Azure-IAC-Terraform"
  }
}

# Subnet for Web App
resource "azurerm_subnet" "webapp" {
  name                 = "subnet-webapp"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]
  
  delegation {
    name = "webapp-delegation"
    service_delegation {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

# App Service Plan
resource "azurerm_service_plan" "main" {
  name                = "asp-secure-webapp"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  os_type             = "Linux"
  sku_name            = "B1"

  tags = {
    Environment = "Test"
    Project     = "Azure-IAC-Terraform"
  }
}

# Generate random suffix for unique names
resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

# Web App
resource "azurerm_linux_web_app" "main" {
  name                = "webapp-secure-iac-${random_string.suffix.result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  service_plan_id     = azurerm_service_plan.main.id

  site_config {
    always_on         = false
    minimum_tls_version = "1.2"
    
    application_stack {
      node_version = "18-lts"
    }
  }

  app_settings = {
    "WEBSITE_NODE_DEFAULT_VERSION" = "18-lts"
  }

  tags = {
    Environment = "Test"
    Project     = "Azure-IAC-Terraform"
  }
}

# VNet Integration
resource "azurerm_app_service_virtual_network_swift_connection" "main" {
  app_service_id = azurerm_linux_web_app.main.id
  subnet_id      = azurerm_subnet.webapp.id
}

# Storage Account
resource "azurerm_storage_account" "main" {
  name                     = "stgsecureapp${random_string.suffix.result}"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  
  # Security hardening
  public_network_access_enabled   = false
  allow_nested_items_to_be_public = false
  
  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"]
  }

  tags = {
    Environment = "Test"
    Project     = "Azure-IAC-Terraform"
  }
}
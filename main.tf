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

# Generate random suffix for unique names
resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = "rg-azure-iac-terraform-${random_string.suffix.result}"
  location = "Central India"

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

# App Service Plan - BASIC TIER for VNet Integration
resource "azurerm_service_plan" "main" {
  name                = "asp-secure-webapp"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  os_type             = "Linux"
  sku_name            = "B1"  # Changed back to B1 to support VNet integration

  tags = {
    Environment = "Test"
    Project     = "Azure-IAC-Terraform"
  }
}

# Web App
resource "azurerm_linux_web_app" "main" {
  name                = "webapp-secure-iac-${random_string.suffix.result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  service_plan_id     = azurerm_service_plan.main.id

  site_config {
    always_on         = true   # Can be enabled with B1 tier
    minimum_tls_version = "1.2"
    
    application_stack {
      node_version = "18-lts"
    }
  }

  app_settings = {
    "WEBSITE_NODE_DEFAULT_VERSION" = "18-lts"
    "SCM_DO_BUILD_DURING_DEPLOYMENT" = "false"
    "WEBSITE_RUN_FROM_PACKAGE" = "0"
    "POST_BUILD_SCRIPT_PATH" = "echo '<!DOCTYPE html><html><head><title>Secure Azure Infrastructure</title></head><body><h1>Azure Infrastructure Deployed</h1><p>VNet Integration: Active</p><p>Location: Central India</p></body></html>' > /home/site/wwwroot/index.html"
  }

  tags = {
    Environment = "Test"
    Project     = "Azure-IAC-Terraform"
  }
}

# VNet Integration - REQUIRED for exam
resource "azurerm_app_service_virtual_network_swift_connection" "main" {
  app_service_id = azurerm_linux_web_app.main.id
  subnet_id      = azurerm_subnet.webapp.id
}

# Storage Account - More permissive settings
resource "azurerm_storage_account" "main" {
  name                     = "stgsecureapp${random_string.suffix.result}"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  
  # Security settings (as much as possible within quota limits)
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
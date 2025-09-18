# Virtual Network
resource "azurerm_virtual_network" "main" {
  name                = var.vnet_name
  address_space       = var.vnet_address_space
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = var.common_tags
}

# Subnets
resource "azurerm_subnet" "subnets" {
  for_each = var.subnet_configs

  name                 = "subnet-${each.key}"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = each.value.address_prefixes
  service_endpoints    = try(each.value.service_endpoints, [])

  dynamic "delegation" {
    for_each = try(each.value.delegation, null) != null ? [each.value.delegation] : []
    content {
      name = delegation.value.name
      service_delegation {
        name    = delegation.value.service_delegation.name
        actions = delegation.value.service_delegation.actions
      }
    }
  }
}

# Network Security Group for Private Endpoints
resource "azurerm_network_security_group" "private_endpoints" {
  name                = "nsg-private-endpoints"
  location            = var.location
  resource_group_name = var.resource_group_name

  # Allow inbound traffic from VNet
  security_rule {
    name                       = "AllowVnetInbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  # Deny all other inbound traffic
  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = var.common_tags
}

# Associate NSG with Private Endpoints subnet
resource "azurerm_subnet_network_security_group_association" "private_endpoints" {
  subnet_id                 = azurerm_subnet.subnets["private_endpoints"].id
  network_security_group_id = azurerm_network_security_group.private_endpoints.id
}

# Network Security Group for Web App Integration
resource "azurerm_network_security_group" "webapp" {
  name                = "nsg-webapp-integration"
  location            = var.location
  resource_group_name = var.resource_group_name

  # Allow outbound to internet for Web App
  security_rule {
    name                       = "AllowInternetOutbound"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "Internet"
  }

  # Allow internal VNet communication
  security_rule {
    name                       = "AllowVnetInbound"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  tags = var.common_tags
}

# Associate NSG with Web App Integration subnet
resource "azurerm_subnet_network_security_group_association" "webapp" {
  subnet_id                 = azurerm_subnet.subnets["webapp"].id
  network_security_group_id = azurerm_network_security_group.webapp.id
}
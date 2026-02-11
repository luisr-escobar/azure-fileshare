provider "azurerm" {
  features {}
}

variable "location" {
  default = "East US"
}

variable "resource_group_name" {
  default = "rg-fileshare-cad"
}

variable "vpn_root_cert_data" {
  description = "Base64 encoded public root certificate data for P2S VPN. Leave empty to deploy Gateway without cert (update later) or provide via tfvars."
  default     = ""
}

resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
}

# --- Networking ---

resource "azurerm_virtual_network" "main" {
  name                = "vnet-fileshare"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "gateway_subnet" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_subnet" "storage_subnet" {
  name                 = "snet-storage"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.2.0/24"]
}

# --- VPN Gateway ---

resource "azurerm_public_ip" "vpn_pip" {
  name                = "pip-vpn-gateway"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_virtual_network_gateway" "vpn" {
  name                = "vpngw-fileshare"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  type     = "Vpn"
  vpn_type = "RouteBased"

  active_active = false
  enable_bgp    = false
  sku           = "VpnGw1"

  ip_configuration {
    name                          = "vnetGatewayConfig"
    public_ip_address_id          = azurerm_public_ip.vpn_pip.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.gateway_subnet.id
  }

  vpn_client_configuration {
    address_space = ["172.16.201.0/24"] # VPN Client Pool

    # If variable provided, configure root cert. Otherwise, user must update post-deploy or via portal.
    dynamic "root_certificate" {
      for_each = var.vpn_root_cert_data != "" ? [1] : []
      content {
        name             = "P2SRootCert"
        public_cert_data = var.vpn_root_cert_data
      }
    }
  }
}

# --- Storage Account ---

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "azurerm_storage_account" "main" {
  name                     = "stcad${random_string.suffix.result}"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Premium"
  account_replication_type = "LRS"
  account_kind             = "FileStorage"

  # Secure transfer required
  https_traffic_only_enabled = true
  min_tls_version          = "TLS1_2"

  # Networking
  # Must be enabled for Terraform to create the share via the management plane from your PC
  public_network_access_enabled = true

  azure_files_authentication {
    directory_type = "AADKERB"
  }
}

resource "azurerm_storage_share" "cad_share" {
  name                 = "cad-projects"
  storage_account_id   = azurerm_storage_account.main.id
  quota                = 100 # GB
}

# --- Private Endpoint ---

resource "azurerm_private_endpoint" "storage_pe" {
  name                = "pe-storage-file"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = azurerm_subnet.storage_subnet.id

  private_service_connection {
    name                           = "psc-storage-file"
    private_connection_resource_id = azurerm_storage_account.main.id
    subresource_names              = ["file"]
    is_manual_connection           = false
  }

  # In a real setup, you'd integrate with Private DNS Zone here.
  # For simplicity, we'll let the user rely on host file or IP mapping initially,
  # but standard practice is a Private DNS Zone linked to the VNet.
}

resource "azurerm_private_dns_zone" "file_core" {
  name                = "privatelink.file.core.windows.net"
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "file_core_link" {
  name                  = "link-vnet"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.file_core.name
  virtual_network_id    = azurerm_virtual_network.main.id
}

resource "azurerm_private_dns_a_record" "storage_a_record" {
  name                = azurerm_storage_account.main.name
  zone_name           = azurerm_private_dns_zone.file_core.name
  resource_group_name = azurerm_resource_group.main.name
  ttl                 = 300
  records             = [azurerm_private_endpoint.storage_pe.private_service_connection[0].private_ip_address]
}


# --- Outputs ---

output "storage_account_name" {
  value = azurerm_storage_account.main.name
}

output "file_share_name" {
  value = azurerm_storage_share.cad_share.name
}

output "resource_group_name" {
  value = azurerm_resource_group.main.name
}

output "vpn_gateway_name" {
  value = azurerm_virtual_network_gateway.vpn.name
}

output "storage_account_private_ip" {
  value = azurerm_private_endpoint.storage_pe.private_service_connection[0].private_ip_address
}

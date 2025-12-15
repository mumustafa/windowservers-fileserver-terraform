###############################################################################
# PROVIDER
###############################################################################
provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
  # If you want to use your user identity (MFA) to avoid CA blocks, uncomment:
  # use_cli = true
}


###############################################################################
# DATA SOURCES (existing resources)
###############################################################################
data "azurerm_resource_group" "vm_rg" {
  name = var.vm_rg_name
}

data "azurerm_resource_group" "vnet_rg" {
  for_each = var.region_networks
  name     = each.value.vnet_rg_name
}

data "azurerm_virtual_network" "vnet" {
  for_each            = var.region_networks
  name                = each.value.vnet_name
  resource_group_name = data.azurerm_resource_group.vnet_rg[each.key].name
}

data "azurerm_subnet" "subnet" {
  for_each             = var.region_networks
  name                 = each.value.subnet_name
  virtual_network_name = data.azurerm_virtual_network.vnet[each.key].name
  resource_group_name  = data.azurerm_resource_group.vnet_rg[each.key].name
}

###############################################################################
# LOCALS (instance expansion + naming)
###############################################################################
locals {
  # Region suffix for short names
  region_suffix = {
    canadacentral = "CC"
    canadaeast    = "CE"
  }

  # Build the instances and names like VM01-CC, VM02-CC, VM01-CE
  vm_instances = flatten([
    for region, count in var.vm_distribution : [
      for i in range(count) : {
        region = region
        seq    = format("%02d", i + 1)
        name   = "VM${format("%02d", i + 1)}-${lookup(local.region_suffix, region, upper(substr(region, 0, 2)))}"
      }
    ]
  ])
}

###############################################################################
# NETWORK SECURITY GROUPS (per region; NIC-level attach)
###############################################################################
resource "azurerm_network_security_group" "nsg" {
  # One NSG per region, created in the VM RG, located in that region
  for_each = var.region_networks

  name                = "nsg-${lookup(local.region_suffix, each.key, substr(each.key, 0, 2))}-rdp"
  location            = each.key
  resource_group_name = data.azurerm_resource_group.vm_rg.name

  # Example allow RDP (internal only, since no public IPs)
  # Consider tightening source_address_prefix to your corp ranges.
  security_rule {
    name                       = "Allow-RDP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

###############################################################################
# NETWORK INTERFACES (NO PUBLIC IPS)
###############################################################################
resource "azurerm_network_interface" "nic" {
  for_each = { for inst in local.vm_instances : inst.name => inst }

  name                = "nic-${each.key}"
  location            = each.value.region
  resource_group_name = data.azurerm_resource_group.vm_rg.name

  ip_configuration {
    name                          = "ipconfig"
    subnet_id                     = data.azurerm_subnet.subnet[each.value.region].id
    private_ip_address_allocation = "Dynamic"
    # No public_ip_address_id -> private only
  }
}

# Associate each NIC with the NSG in its region
resource "azurerm_network_interface_security_group_association" "nsg_assoc" {
  for_each = azurerm_network_interface.nic

  network_interface_id      = each.value.id
  network_security_group_id = azurerm_network_security_group.nsg[each.value.location].id
}

###############################################################################
# WINDOWS SERVER 2022 VMs
###############################################################################
resource "azurerm_windows_virtual_machine" "vm" {
  for_each            = azurerm_network_interface.nic
  name                = each.key
  resource_group_name = data.azurerm_resource_group.vm_rg.name
  location            = each.value.location
  size                = "Standard_DS2_v2"
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  bypass_platform_safety_checks_on_user_schedule_enabled = true
  patch_mode = "AutomaticByPlatform"
  network_interface_ids = [each.value.id]

  # Ensure NetBIOS name <= 15 chars (our names already are, e.g., VM01-CC)
  computer_name = each.key

  os_disk {
    name                 = "osdisk-${each.key}"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter"
    version   = "latest"
  }

  tags = {
    environment = "production"
    project     = "fileserver-upgrade"
    Terraform   = "true"
  }
}
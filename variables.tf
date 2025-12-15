###############################################################################
# VARIABLES
###############################################################################
# Azure subscription ID
variable "subscription_id" {
  type        = string
  description = "Azure subscription ID where resources will be deployed"
  sensitive   = true
}

# VMs resource group (where NICs, NSGs, and VMs will live)
variable "vm_rg_name" {
  type    = string
  default = "cc-vms-rg"
}

# How many VMs per region (change values to scale)
# Example: 2 in Canada Central, 1 in Canada East
variable "vm_distribution" {
  type = map(number)
  default = {
    canadacentral = 1
    canadaeast    = 0
  }
}

# Existing per-region network objects (all referenced via data sources)
# Both VNets are in the same RG: "network-cc-rg"
variable "region_networks" {
  type = map(object({
    vnet_rg_name = string
    vnet_name    = string
    subnet_name  = string
  }))
  default = {
    canadacentral = {
      vnet_rg_name = "network-cc-rg"
      vnet_name    = "cc-main-vnet"
      subnet_name  = "default" # <-- change if your subnet name differs
    }
    canadaeast = {
      vnet_rg_name = "network-cc-rg"
      vnet_name    = "ce-main-vnet"
      subnet_name  = "default" # <-- change if your subnet name differs
    }
  }
}

# Local admin for the Windows Server VM
variable "admin_username" {
  type    = string
  default = "azureadmin"
}

variable "admin_password" {
  type      = string
  sensitive = true
}

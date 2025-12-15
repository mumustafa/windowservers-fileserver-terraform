# Windows Fileserver Upgrade - Terraform Infrastructure

## Overview
This Terraform configuration deploys Windows Server 2022 virtual machines across multiple Azure regions (Canada Central and Canada East) for a fileserver upgrade project. The infrastructure is designed for easy scaling and regional distribution.

## Architecture

### What This Creates
- **Windows Server 2022 VMs**: Automatically deployed across specified regions
- **Network Interfaces (NICs)**: One per VM with private IPs (no public IPs)
- **Network Security Groups (NSGs)**: Per-region NSGs with RDP access rules
- **Resource Organization**: All resources deployed to a single resource group, but distributed across regions

### Naming Convention
VMs follow a standardized naming pattern: `VM##-{REGION_CODE}`
- **Canada Central**: `VM01-CC`, `VM02-CC`, etc.
- **Canada East**: `VM01-CE`, `VM02-CE`, etc.

Sequential numbers reset per region, making it easy to identify VM location at a glance.

## Prerequisites

1. **Azure Subscription**: Valid Azure subscription with contributor/owner access
2. **Existing Resources**:
   - Resource Group: `cc-vms-rg` (for VMs, NICs, NSGs)
   - Resource Group: `network-cc-rg` (for existing VNets)
   - VNet in Canada Central: `cc-main-vnet`
   - VNet in Canada East: `ce-main-vnet`
   - Subnets: `default` in each VNet
3. **Terraform**: Version 0.13+ with Azure provider
4. **Authentication**: Azure CLI (`az login`) or Service Principal

## Variables Explained

### `vm_rg_name` (default: `"cc-vms-rg"`)
The resource group where all VMs, NICs, and NSGs will be created. This must already exist.

### `vm_distribution` (default: `canadacentral = 1, canadaeast = 0`)
**This is your scaling control.** A map that defines how many VMs to deploy in each region.

**Examples:**
```hcl
# Deploy 3 VMs in Canada Central, 2 in Canada East
vm_distribution = {
  canadacentral = 3
  canadaeast    = 2
}

# Deploy only in Canada Central
vm_distribution = {
  canadacentral = 5
  canadaeast    = 0
}
```

### `region_networks`
Maps each region to its existing network infrastructure:
- `vnet_rg_name`: Resource group containing the VNet
- `vnet_name`: Name of the Virtual Network
- `subnet_name`: Subnet where VMs will be deployed

**Current Configuration:**
```hcl
canadacentral = {
  vnet_rg_name = "network-cc-rg"
  vnet_name    = "cc-main-vnet"
  subnet_name  = "default"
}
canadaeast = {
  vnet_rg_name = "network-cc-rg"
  vnet_name    = "ce-main-vnet"
  subnet_name  = "default"
}
```

### `admin_username` (default: `"azureadmin"`)
Local administrator username for all Windows Server VMs.

### `admin_password` (required, sensitive)
Local administrator password. Must meet Azure password complexity requirements.

### `subscription_id` (required, sensitive)
Your Azure subscription ID (GUID format). This determines where all resources will be deployed.

## Authentication & Configuration

### Option 1: Environment Variable (Recommended)
Set the subscription ID as an environment variable to avoid storing it in files:

```bash
# Windows PowerShell
$env:TF_VAR_subscription_id="your-subscription-id-here"

# Linux/Mac
export TF_VAR_subscription_id="your-subscription-id-here"
```

Then run Terraform commands normally - it will automatically pick up the variable.

### Option 2: terraform.tfvars File
Create a `terraform.tfvars` file (already in .gitignore):

```hcl
subscription_id = "your-subscription-id-here"
admin_password  = "YourSecurePassword123!"
```

### Option 3: Command Line
Pass variables directly when running commands:

```bash
terraform plan -var="subscription_id=your-sub-id" -var="admin_password=YourPassword123!"
```

### Option 4: Use Azure CLI Authentication
If you're already logged in via `az login`, you can let Terraform use your current context by uncommenting in [main.tf](main.tf):

```hcl
provider "azurerm" {
  features {}
  use_cli = true  # Uncomment this line
  # subscription_id can be omitted when using CLI auth with default subscription
}

## How to Use

### 1. Initial Deployment

```bash
# Initialize Terraform
terraform init

# Set your subscription ID (choose one method from Authentication section above)
$env:TF_VAR_subscription_id="your-subscription-id"

# Create a terraform.tfvars file with your admin password
echo 'admin_password = "YourSecurePassword123!"' > terraform.tfvars

# Preview what will be created
terraform plan

# Deploy the infrastructure
terraform apply
```

### 2. Scaling VMs

To add or remove VMs, simply modify the `vm_distribution` variable:

**Add 2 more VMs to Canada Central:**
```hcl
# In terraform.tfvars or via command line
vm_distribution = {
  canadacentral = 3  # Was 1, now 3 = 2 new VMs
  canadaeast    = 0
}
```

**Add VMs to Canada East:**
```hcl
vm_distribution = {
  canadacentral = 1
  canadaeast    = 2  # Add 2 VMs in Canada East
}
```

Then run:
```bash
terraform plan   # Review changes
terraform apply  # Apply changes
```

### 3. Destroying Resources

```bash
# Remove all infrastructure
terraform destroy
```

## Key Logic & Design Decisions

### Regional Distribution Logic
The `locals` block in [main.tf](main.tf) contains the VM instance expansion logic:

```hcl
vm_instances = flatten([
  for region, count in var.vm_distribution : [
    for i in range(count) : {
      region = region
      seq    = format("%02d", i + 1)
      name   = "VM${format("%02d", i + 1)}-${region_suffix[region]}"
    }
  ]
])
```

**How it works:**
1. Iterates through each region in `vm_distribution`
2. For each region, creates `count` number of VM instances
3. Assigns sequential numbers (01, 02, 03...) per region
4. Generates standardized names (VM01-CC, VM02-CC, etc.)

### Network Security
- **No Public IPs**: All VMs are private-only for security
- **NSG per Region**: Each region gets its own NSG
- **RDP Access**: Currently allows RDP (port 3389) from any source
  - ⚠️ **Security Note**: Consider restricting `source_address_prefix` to your corporate IP ranges

### VM Configuration
- **OS**: Windows Server 2022 Datacenter (latest)
- **Size**: Standard_DS2_v2 (2 vCPUs, 7 GB RAM)
- **OS Disk**: Standard_LRS (cost-optimized)
- **Patching**: AutomaticByPlatform mode enabled
- **Computer Name**: Matches VM resource name (NetBIOS-compliant)

## File Structure

```
.
├── main.tf              # Main infrastructure definitions
├── variables.tf         # Variable declarations and defaults
├── terraform.tfvars     # Your variable values (not in git - contains password)
├── .gitignore          # Excludes state files and sensitive data
├── .terraform.lock.hcl # Dependency lock file
└── Scaling             # Quick reference for scaling examples
```

## Security Best Practices

### Secrets Management
- **Never commit** `terraform.tfvars` containing passwords to git
- **Use Azure Key Vault** for production password management
- **Consider** using `use_cli = true` in the provider block for MFA-based authentication

### Network Security
Current NSG rule allows RDP from anywhere (`*`). For production:

```hcl
source_address_prefix = "10.0.0.0/8"  # Your corporate network range
```

## Common Tasks

### Check Current Infrastructure
```bash
terraform show
```

### View State
```bash
terraform state list
```

### Get VM IP Addresses
```bash
terraform state show 'azurerm_network_interface.nic["VM01-CC"]' | grep private_ip_address
```

### Refresh State
```bash
terraform refresh
```

## Troubleshooting

### VMs Not Created
- Verify resource groups exist: `cc-vms-rg` and `network-cc-rg`
- Check VNet and subnet names match your Azure resources
- Ensure subscription ID is correct

### Authentication Errors
- Run `az login` to authenticate
- Or uncomment `use_cli = true` in the provider block

### NetBIOS Name Length Error
VM names are kept under 15 characters by design (e.g., `VM01-CC` = 7 chars)

## Tags
All VMs are tagged with:
- `environment`: production
- `project`: fileserver-upgrade
- `Terraform`: true

Use these for cost tracking and resource management in Azure.

## Future Enhancements
- [ ] Add data disks for file storage
- [ ] Implement Azure Backup
- [ ] Add availability sets or zones
- [ ] Configure file share services
- [ ] Implement Azure Monitor alerts
- [ ] Add more granular NSG rules

## Git Workflow

This repository maintains a clean, single-commit history for security and clarity. For detailed information about:
- How this repository's history was created
- Squashing commits before pull requests
- Git best practices for infrastructure code

See [GIT_WORKFLOW.md](GIT_WORKFLOW.md) for comprehensive guidance.

## Support
For questions or issues with this infrastructure, refer to the Terraform state file or reach out to the infrastructure team.

---
**Last Updated**: December 2025  
**Terraform Version**: Compatible with 0.13+  
**Azure Provider**: azurerm

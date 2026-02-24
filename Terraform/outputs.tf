# -----------------------------------------------------------------------------
# OUTPUTS FILE
# After "terraform apply" completes, these values are printed to the terminal.
# They're useful so you don't have to go hunting in the Azure portal for things
# like the VM's IP address. Outputs can also be referenced by other Terraform
# configurations if you ever split the infra into modules.
# -----------------------------------------------------------------------------

# Handy to have when logging into the Azure CLI or portal to check resources
output "resource_group_name" {
  description = "Name of the Azure Resource Group"
  value       = azurerm_resource_group.main.name
}

# The name of the VM as it appears in the Azure portal
output "vm_name" {
  description = "Name of the Azure Virtual Machine"
  value       = azurerm_linux_virtual_machine.main.name
}

# The public IP is dynamic so we don't know it until after apply.
# Note: with Basic SKU + Dynamic allocation, this may show as empty until
# the VM is fully running — you can re-run "terraform output" after a minute.
output "public_ip_address" {
  description = "Public IP address of the VM — use this to SSH and access the app"
  value       = azurerm_public_ip.main.ip_address
}

# Copy-paste this directly into your terminal to SSH into the VM
# e.g: ssh azureuser@20.251.154.215
output "ssh_command" {
  description = "Ready-to-use SSH command to connect to the VM"
  value       = "ssh ${var.admin_username}@${azurerm_public_ip.main.ip_address}"
}

# After Ansible deploys the Docker container, open this URL in a browser
# to verify the app is live. Port 8080 is opened in the NSG.
output "app_url" {
  description = "URL to access the deployed web application"
  value       = "http://${azurerm_public_ip.main.ip_address}:8080"
}

# VNet ID is useful if we ever want to peer this network with another VNet
# or reference it from a separate Terraform module/workspace
output "vnet_id" {
  description = "Virtual Network ID"
  value       = azurerm_virtual_network.main.id
}

# Subnet ID may be needed if we add more resources (e.g. a second VM or
# a load balancer) that also need to live in the same subnet
output "subnet_id" {
  description = "Subnet ID"
  value       = azurerm_subnet.main.id
}

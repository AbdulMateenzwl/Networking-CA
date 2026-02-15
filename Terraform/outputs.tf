output "resource_group_name" {
  description = "Name of the Azure Resource Group"
  value       = azurerm_resource_group.main.name
}

output "vm_name" {
  description = "Name of the Azure Virtual Machine"
  value       = azurerm_linux_virtual_machine.main.name
}

output "public_ip_address" {
  description = "Public IP address of the VM — use this to SSH and access the app"
  value       = azurerm_public_ip.main.ip_address
}

output "ssh_command" {
  description = "Ready-to-use SSH command to connect to the VM"
  value       = "ssh ${var.admin_username}@${azurerm_public_ip.main.ip_address}"
}

output "app_url" {
  description = "URL to access the deployed web application"
  value       = "http://${azurerm_public_ip.main.ip_address}:8080"
}

output "vnet_id" {
  description = "Virtual Network ID"
  value       = azurerm_virtual_network.main.id
}

output "subnet_id" {
  description = "Subnet ID"
  value       = azurerm_subnet.main.id
}

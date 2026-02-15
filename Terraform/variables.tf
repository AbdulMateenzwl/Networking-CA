variable "project_name" {
  description = "Base name used for all resources"
  type        = string
  default     = "docker-app"
}

variable "location" {
  description = "Azure region — must be one allowed by your student account"
  type        = string
  default     = "norwayeast"  

}

variable "vm_size" {
  description = "Azure VM size — student accounts support small sizes"
  type        = string
  default     = "Standard_B1s"  
}

variable "admin_username" {
  description = "Linux admin username for the VM"
  type        = string
  default     = "azureuser"
}

variable "ssh_public_key_path" {
  description = "Path to your SSH public key file"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}
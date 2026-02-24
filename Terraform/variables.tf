# -----------------------------------------------------------------------------
# VARIABLES FILE
# Variables make the config reusable — instead of hard-coding values like the
# region or VM size in main.tf, we define them here with a description and a
# default. The actual values we use are set in terraform.tfvars.
# -----------------------------------------------------------------------------

# Used as a prefix for every resource name (e.g. NetworkingCA-vm, NetworkingCA-nsg)
# Makes it easy to identify all resources belonging to this project in the portal
variable "project_name" {
  description = "Base name used for all resources"
  type        = string
  default     = "docker-app"
}

# Azure has many regions worldwide. Student accounts are often restricted to
# certain ones. northeurope (Ireland) and norwayeast both tend to work.
# This is overridden in terraform.tfvars.
variable "location" {
  description = "Azure region — must be one allowed by your student account"
  type        = string
  default     = "norwayeast"
}

# VM size determines how much CPU and RAM the machine gets.
# Standard_B1s = 1 vCPU, 1GB RAM — the smallest (and cheapest) option.
# Good enough to run Docker + our lightweight nginx container.
variable "vm_size" {
  description = "Azure VM size — student accounts support small sizes"
  type        = string
  default     = "Standard_B1s"
}

# The Linux user that Terraform creates on the VM during provisioning.
# This is the username we SSH in with (e.g. ssh azureuser@<ip>)
# and also the user Ansible connects as.
variable "admin_username" {
  description = "Linux admin username for the VM"
  type        = string
  default     = "mateen"
}

# Path to the SSH public key on our local machine.
# Terraform reads this file and injects the key into the VM so we can
# SSH in without a password. The matching private key stays on our machine.
# Make sure you've already run: ssh-keygen -t rsa before applying.
variable "ssh_public_key_path" {
  description = "Path to your SSH public key file"
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}
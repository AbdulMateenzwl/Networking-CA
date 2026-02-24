# -----------------------------------------------------------------------------
# TERRAFORM VARIABLE VALUES (tfvars)
# This file overrides the defaults defined in variables.tf.
# Terraform automatically loads terraform.tfvars so no -var-file flag needed.
# Do NOT commit sensitive values (passwords, secrets) here — use environment
# variables or a secrets manager for those instead.
# -----------------------------------------------------------------------------

# All Azure resources will be named with this prefix, e.g. NetworkingCA-vm
project_name        = "NetworkingCA"

# northeurope (Ireland) — available on our student subscription
location            = "northeurope"

# Cheapest VM size available — 1 vCPU / 1GB RAM, enough for this project
vm_size             = "Standard_B1s"

# The username created on the VM — used for SSH and Ansible connections
admin_username      = "mateen"

# Terraform reads this file to get our public key and push it to the VM
# Make sure the matching private key (~/.ssh/id_ed25519) exists locally
ssh_public_key_path = "~/.ssh/id_ed25519.pub"
# -----------------------------------------------------------------------------
# TERRAFORM CONFIGURATION BLOCK
# This tells Terraform which providers we need and what version of Terraform
# itself is required. Without this, tf wouldn't know to download the Azure
# plugin automatically.
# -----------------------------------------------------------------------------
terraform {
  required_providers {
    # azurerm is the official HashiCorp provider for Microsoft Azure.
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
  # Minimum Terraform CLI version needed to run this config
  required_version = ">= 1.3.0"
}

# -----------------------------------------------------------------------------
# AZURE PROVIDER
# This authenticates Terraform with Azure. The empty features {} block is
# required by the provider even if we're not customising any features.
# Credentials come from environment variables or
# az login on the local machine.
# -----------------------------------------------------------------------------
provider "azurerm" {
  features {}
}

# -----------------------------------------------------------------------------
# RESOURCE GROUP
# A Resource Group is just a logical container in Azure — every resource
# (VM, network, IP...) must belong to one. Deleting the RG deletes everything
# inside it, which is handy for cleanup after the project.
# The name is built dynamically using the project_name variable so we don't
# have to hard-code it everywhere.
# -----------------------------------------------------------------------------
resource "azurerm_resource_group" "main" {
  name     = "${var.project_name}-rg"
  location = var.location
}

# -----------------------------------------------------------------------------
# VIRTUAL NETWORK (VNet)
# A VNet is the private network in Azure — like a LAN in the cloud.
# 10.0.0.0/16 gives us 65,536 possible IP addresses to work with inside
# this network. Nothing outside can reach resources here unless we
# explicitly open ports via the NSG below.
# We reference the RG location/name from the resource above instead of
# repeating the variable — this is the recommended Terraform pattern.
# -----------------------------------------------------------------------------
resource "azurerm_virtual_network" "main" {
  name                = "${var.project_name}-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

# -----------------------------------------------------------------------------
# SUBNET
# A subnet is a smaller slice of the VNet address space.
# 10.0.1.0/24 gives us 256 addresses (10.0.1.0 – 10.0.1.255).
# Azure reserves 5 of those for itself, so we get 251 usable ones.
# Our VM's NIC will get a private IP from this range.
# -----------------------------------------------------------------------------
resource "azurerm_subnet" "main" {
  name                 = "${var.project_name}-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]
}

# -----------------------------------------------------------------------------
# NETWORK SECURITY GROUP (NSG) — basically the cloud firewall
# Rules are evaluated by priority (lower number = checked first).
# If a rule matches, Azure stops checking further rules.
# All traffic not explicitly allowed is denied by default.
# We define three inbound rules to allow the traffic our app needs.
# -----------------------------------------------------------------------------
resource "azurerm_network_security_group" "main" {
  name                = "${var.project_name}-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  # Rule 1 — SSH (port 22)
  # Needed so we can connect to the VM from our local machine to run Ansible
  # or debug things manually. source_address_prefix = "*" means any IP can try
  # to connect — in production you'd lock this down to your own IP.
  security_rule {
    name                       = "Allow-SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"   # source port is random (ephemeral), so always *
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Rule 2 — HTTP (port 80)
  # Standard web traffic port. Even though our app runs on 8080, having 80
  # open allows a reverse proxy or future nginx setup to work.
  security_rule {
    name                       = "Allow-HTTP"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Rule 3 — App Port (8080)
  # Our Docker container maps host port 8080 → container port 80.
  # Without this rule, Azure's firewall would silently drop all
  # traffic to 8080 even if the container is running fine.
  security_rule {
    name                       = "Allow-App-Port"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8080"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# -----------------------------------------------------------------------------
# SUBNET → NSG ASSOCIATION
# Attaching the NSG to the subnet means the firewall rules apply to ALL
# resources inside that subnet, not just one VM. Good for when you scale up.
# -----------------------------------------------------------------------------
resource "azurerm_subnet_network_security_group_association" "main" {
  subnet_id                 = azurerm_subnet.main.id
  network_security_group_id = azurerm_network_security_group.main.id
}

# -----------------------------------------------------------------------------
# PUBLIC IP ADDRESS
# This is how the outside world reaches our VM. "Dynamic" means Azure assigns
# the IP when the VM starts — it can change if the VM is deallocated and
# restarted. "Basic" SKU is used because Standard is often restricted on
# student/free-tier Azure accounts.
# -----------------------------------------------------------------------------
resource "azurerm_public_ip" "main" {
  name                = "${var.project_name}-pip"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  allocation_method   = "Dynamic" # Basic SKU requires Dynamic allocation
  sku                 = "Basic"   # Standard SKU is often blocked for students
}

# -----------------------------------------------------------------------------
# NETWORK INTERFACE (NIC)
# The NIC is the virtual network card attached to the VM.
# It gets both a private IP (from the subnet range) and the public IP above.
# The ip_configuration block wires everything together.
# -----------------------------------------------------------------------------
resource "azurerm_network_interface" "main" {
  name                = "${var.project_name}-nic"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.main.id
    private_ip_address_allocation = "Dynamic" # Azure picks a free IP from the subnet
    public_ip_address_id          = azurerm_public_ip.main.id
  }
}

# -----------------------------------------------------------------------------
# NIC → NSG ASSOCIATION
# We also attach the NSG directly to the NIC as a second layer of protection.
# Azure applies both the subnet-level and NIC-level NSG rules — both must
# allow traffic for it to reach the VM.
# -----------------------------------------------------------------------------
resource "azurerm_network_interface_security_group_association" "main" {
  network_interface_id      = azurerm_network_interface.main.id
  network_security_group_id = azurerm_network_security_group.main.id
}

# -----------------------------------------------------------------------------
# LINUX VIRTUAL MACHINE
# The actual VM that runs our Docker container. Key decisions made here:
#   - Password authentication disabled — SSH key only (more secure)
#   - Ubuntu 22.04 LTS chosen because it's stable and widely supported
#   - Standard_LRS disk is the cheapest option (locally redundant storage)
#   - Size comes from variables so it's easy to change without touching this file
# -----------------------------------------------------------------------------
resource "azurerm_linux_virtual_machine" "main" {
  name                = "${var.project_name}-vm"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  size                = var.vm_size

  admin_username = var.admin_username
  # Disabling password auth forces SSH key usage — best practice for any VM
  disable_password_authentication = true

  # Attach the NIC we created above — this is how the VM joins the network
  network_interface_ids = [
    azurerm_network_interface.main.id,
  ]

  # Terraform reads our local public key file and injects it into the VM
  # during provisioning via cloud-init. This is what allows `ssh azureuser@<ip>`
  # to work without a password.
  admin_ssh_key {
    username   = var.admin_username
    public_key = file(var.ssh_public_key_path)
  }

  # OS disk configuration — 30GB is enough for Ubuntu + Docker + our small app
  os_disk {
    caching              = "ReadWrite"   # Caching improves disk read/write speed
    storage_account_type = "Standard_LRS" # Cheapest disk type, fine for dev/student use
    disk_size_gb         = 30
  }

  # Ubuntu 24.04 LTS (Noble Numbat) — the offer name is a bit odd but this
  # is the correct identifier in the Azure marketplace for Ubuntu 24.04.
  # Using version = "latest" so Azure always picks the most patched image.
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-noble"
    sku       = "24_04-lts"
    version   = "latest"
  }
}
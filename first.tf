# Configure the Microsoft Azure Provider
provider "azurerm" {
 alias  = "east"
 region = "us-east-1"
 # The "feature" block is required for AzureRM provider 2.x.
 # If you're using version 1.x, the "features" block is not allowed.
 version = "~>2.0"
 features {}
}


# Create a resource group if it doesn't exist
resource "azurerm_resource_group" "terraformgroup" {
 name = "my-gr"
 location = "eastus"
 tags = {
   environment = "Terraform Demo"
 }
}

# Create virtual network
resource "azurerm_virtual_network" "terraformnetwork" {
 name = "Vnet"
 address_space = ["10.0.0.0/16"]
 location = "eastus"
 resource_group_name = azurerm_resource_group.terraformgroup.name
 tags = {
   environment = "Terraform Demo"
 }
}

# Create subnet
resource "azurerm_subnet" "terraformsubnet" {
 name = "Subnet"
 resource_group_name = azurerm_resource_group.terraformgroup.name
 virtual_network_name = azurerm_virtual_network.terraformnetwork.name
 address_prefixes = ["10.0.1.0/24"]
}

# Create public IPs
resource "azurerm_public_ip" "terraformpublicip" {
 name = "PublicIP"
 location = "eastus"
 resource_group_name = azurerm_resource_group.terraformgroup.name
 allocation_method = "Static"
 tags = {
   environment = "Terraform Demo"
 }
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "terraformnsg" {
 name = "NetworkSecurityGroup"
 location = "eastus"
 resource_group_name = azurerm_resource_group.terraformgroup.name
 security_rule {
   name = "SSH"
   priority = 1001
   direction = "Inbound"
   access = "Allow"
   protocol = "Tcp"
   source_port_range = "*"
   destination_port_range = "22"
   source_address_prefix = "*"
   destination_address_prefix = "*"
 }
 tags = {
   environment = "Terraform Demo"
 }
}

# Create network interface
resource "azurerm_network_interface" "terraformnic" {
 name = "NIC"
 location = "eastus"
 resource_group_name = azurerm_resource_group.terraformgroup.name
 ip_configuration {
 name = "NicConfiguration"
 subnet_id = azurerm_subnet.terraformsubnet.id
 private_ip_address_allocation = "Dynamic"
 public_ip_address_id = azurerm_public_ip.terraformpublicip.id
 }
 tags = {
   environment = "Terraform Demo"
 }
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "examp" {
 network_interface_id = azurerm_network_interface.terraformnic.id
 network_security_group_id = azurerm_network_security_group.terraformnsg.id
}

# Generate random text for a unique storage account name
resource "random_id" "randomI" {
 keepers = {
 # Generate a new ID only when a new resource group is defined
 resource_group = azurerm_resource_group.terraformgroup.name
 }
 byte_length = 8
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "storageaccount" {
 name = "diag${random_id.randomI.hex}"
 resource_group_name = azurerm_resource_group.terraformgroup.name
 location = "eastus"
 account_tier = "Standard"
 account_replication_type = "LRS"
 tags = {
 environment = "Terraform Demo"
 }
}

# Create (and display) an SSH key
resource "tls_private_key" "for_ssh" {
 algorithm = "RSA"
 rsa_bits = 4096
}

output "tls_private_keys" {
 value = tls_private_key.for_ssh.private_key_pem
 sensitive = true
}

# Create virtual machine
resource "azurerm_linux_virtual_machine" "terraformvm" {
 name = "VM16"
 location = "eastus"
 resource_group_name = azurerm_resource_group.terraformgroup.name
 network_interface_ids = [azurerm_network_interface.terraformnic.id]
 size = "Standard_E2s_v3"
 os_disk {
   name = "myOsDisk"
   caching = "ReadWrite"
   storage_account_type = "Premium_LRS"
 }
 source_image_reference {
   publisher = "Canonical"
   offer = "UbuntuServer"
   sku = "18.04-LTS"
   version = "latest"
 }
 computer_name = "vm16"
 admin_username = "azureuser"
 disable_password_authentication = true
 admin_ssh_key {
   username = "azureuser"
   public_key = tls_private_key.for_ssh.public_key_openssh
 }
 boot_diagnostics {
   storage_account_uri = azurerm_storage_account.storageaccount.primary_blob_endpoint
 }
 tags = {
   environment = "Terraform Demo"
 }
}

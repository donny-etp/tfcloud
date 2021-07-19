
terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "2.68.0"
    }
  }
}
provider azurerm {
    version = "=2.68.0"
    features {}
}
# Create virtual network
resource "azurerm_virtual_network" "donnyvnet" {
    name                = "donnyvnet"
    address_space       = ["10.0.0.0/16"]
    location            = "australiasoutheast"
    resource_group_name = "donnylab-rg"

    tags = {
        environment = "Testing"
    }
}
# Create subnet
resource "azurerm_subnet" "donnysubnet01" {
    name                 = "Internal"
    resource_group_name = azurerm_virtual_network.donnyvnet.resource_group_name
    virtual_network_name = azurerm_virtual_network.donnyvnet.name
    address_prefix       = "10.0.1.0/24"
}

resource "azurerm_subnet" "donnysubnet02" {
    name                 = "DMZ"
    resource_group_name = azurerm_virtual_network.donnyvnet.resource_group_name
    virtual_network_name = azurerm_virtual_network.donnyvnet.name
    address_prefix       = "10.0.10.0/24"
}

#Deploy Public IP
resource "azurerm_public_ip" "donnypip1" {
  name                = "donnypip1"
  location            = "australiasoutheast"
  resource_group_name = azurerm_virtual_network.donnyvnet.resource_group_name
  allocation_method   = "Dynamic"
  sku                 = "Basic"
}

#Create NIC
resource "azurerm_network_interface" "donnynic" {
  name                = "donnyvm01-nic"  
  location            = "australiasoutheast"
  resource_group_name = azurerm_virtual_network.donnyvnet.resource_group_name

    ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.donnysubnet01.id 
    private_ip_address_allocation  = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.donnypip1.id
  }
}

#Create Boot Diagnostic Account
 resource "azurerm_storage_account" "sa" {
  name                     = "donnyvmdiagsto" 
  resource_group_name      = azurerm_virtual_network.donnyvnet.resource_group_name
  location                 = "australiasoutheast"
   account_tier            = "Standard"
   account_replication_type = "LRS"

   tags = {
    environment = "Testing"
    CreatedBy = "donny"
   }
  }

#Create Virtual Machine
resource "azurerm_virtual_machine" "donnyv01" {
  name                  = "donnyvm01"  
  location              = "australiasoutheast"
  resource_group_name   = azurerm_virtual_network.donnyvnet.resource_group_name
  network_interface_ids = [azurerm_network_interface.donnynic.id]
  vm_size               = "Standard_B1s"
  delete_os_disk_on_termination = true
  delete_data_disks_on_termination = true

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  storage_os_disk {
    name              = "osdisk1"
    disk_size_gb      = "128"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "donnyvm01"
    admin_username = "vmadmin"
    admin_password = "Password12345!"
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }

boot_diagnostics {
        enabled     = "true"
        storage_uri = azurerm_storage_account.sa.primary_blob_endpoint
    }
}

resource "azurerm_network_security_group" "nsg" {
  name                = "donnynsg"
  location            = azurerm_virtual_network.donnyvnet.location
  resource_group_name = azurerm_virtual_network.donnyvnet.resource_group_name
}

resource "azurerm_network_security_rule" "rule1" {
  name                        = "Web80"
  priority                    = 1001
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_network_security_group.nsg.resource_group_name
  network_security_group_name = azurerm_network_security_group.nsg.name
}

resource "azurerm_network_security_rule" "rule2" {
  name                        = "Web8080"
  priority                    = 1000
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "8080"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_network_security_group.nsg.resource_group_name
  network_security_group_name = azurerm_network_security_group.nsg.name
}

  resource "azurerm_network_security_rule" "rule3" {
  name                        = "SSH"
  priority                    = 1100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_network_security_group.nsg.resource_group_name
  network_security_group_name = azurerm_network_security_group.nsg.name
}

  resource "azurerm_network_security_rule" "rule4" {
  name                        = "Web80Out"
  priority                    = 1000
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "80"
  destination_port_range      = "80"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_network_security_group.nsg.resource_group_name
  network_security_group_name = azurerm_network_security_group.nsg.name
}

#NIC to NSG association
resource "azurerm_network_interface_security_group_association" "association_interface" {
  network_interface_id      = azurerm_network_interface.donnynic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}


provider "azurerm" {
  # Define o provedor Azure que será usado pelo Terraform para provisionar os recursos no Azure.
  features {}

  subscription_id = "6cae8e83-11e9-472b-8c43-2b85cb868054"
  
}

resource "azurerm_resource_group" "rg" {
  # Cria um grupo de recursos no Azure onde todos os recursos relacionados serão armazenados.
  name     = "docker-swarm-rg"
  location = "East US"
}

# Criando uma Virtual Network (VNet)
resource "azurerm_virtual_network" "swarm_vnet" {
  name                = "swarm-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Criando a Sub-rede (Subnet)
resource "azurerm_subnet" "swarm" {
  name                 = "swarm-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.swarm_vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_network_interface" "swarm-master-nic" {
  name                = "swarm-master-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.swarm.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.swarm-master-pip.id  # Usando o IP público do master
  }
}

resource "azurerm_network_interface" "swarm-node-nic" {
  name                = "swarm-node-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.swarm.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.swarm-node-pip.id  # Usando o IP público do node
  }
}

# IP Público para o swarm-master
resource "azurerm_public_ip" "swarm-master-pip" {
  name                = "swarm-master-pip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"  # Corrige o erro anterior sobre IP dinâmico
  sku                 = "Standard"
}

# IP Público para o swarm-node
resource "azurerm_public_ip" "swarm-node-pip" {
  name                = "swarm-node-pip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"  # Corrige o erro anterior sobre IP dinâmico
  sku                 = "Standard"
}


resource "azurerm_network_security_group" "nsg" {
  # Define um grupo de segurança de rede (NSG) para controlar o tráfego para as VMs.
  name                = "docker-swarm-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_network_security_rule" "ssh" {
  # Cria uma regra de segurança para permitir conexões SSH (porta 22).
  name                        = "AllowSSH"
  priority                    = 1001
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.nsg.name
}

resource "azurerm_linux_virtual_machine" "swarm_master" {
  # Cria a VM principal (master) que será o nó líder do Docker Swarm.
  name                = "swarm-master-vm"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.swarm-master-nic.id]
  size                = "Standard_B1s"
  admin_username      = "adminuser"

  disable_password_authentication = true  # Desativa a senha de autenticação.

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("/home/pmacoy/.ssh/id_rsa.pub")  # Certifique-se de apontar para a sua chave pública SSH.
  }

  os_disk {
    # Configura o disco da VM.
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 30
  }

  source_image_reference {
    # Define a imagem do sistema operacional da VM, usando Ubuntu.
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  # boot_diagnostics {
  #   storage_account_uri = azurerm_storage_account.example.primary_blob_endpoint
  #   # Você pode precisar criar uma conta de armazenamento para armazenar os logs de diagnóstico.
  # }
}

resource "azurerm_linux_virtual_machine" "swarm_node" {
  # Cria uma VM adicional que será um nó (worker) no cluster Docker Swarm.
  name                = "swarm-node-vm"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.swarm-node-nic.id]  # Usando a nova NIC aqui
  size                = "Standard_B1s"  # Tipo da VM (mesmo tamanho pequeno).
  admin_username      = "adminuser"

  disable_password_authentication = true  # Desativa a senha de autenticação.

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("/home/pmacoy/.ssh/id_rsa.pub")  # Certifique-se de apontar para a sua chave pública SSH.
  }
  
  os_disk {
    # Configura o disco da VM.
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 30
  }

  source_image_reference {
    # Define a imagem do sistema operacional da VM, usando Ubuntu.
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  # boot_diagnostics {
  #   storage_account_uri = azurerm_storage_account.example.primary_blob_endpoint
  # }
}

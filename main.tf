# Criação do grupo de recursos
resource "azurerm_resource_group" "main" {
  name     = "docker-swarm-rg"
  location = "East US"
}

# Criação da rede virtual
resource "azurerm_virtual_network" "main" {
  name                = "swarm-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

# Criação da sub-rede
resource "azurerm_subnet" "swarm-subnet" {
  name                 = "swarm-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Criação do grupo de segurança de rede
resource "azurerm_network_security_group" "swarm_nsg" {
  name                = "swarm-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTP"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTPS"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Criação da interface de rede do nó mestre
resource "azurerm_network_interface" "swarm-master-nic" {
  name                = "swarm-master-nic"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.swarm-subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.swarm-master-pip.id
  }
}

# Criação da interface de rede dos nós trabalhadores
resource "azurerm_network_interface" "swarm-node-nic" {
  count               = var.node_count
  name                = "swarm-node-nic-${count.index}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.swarm-subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.swarm-node-pip[count.index].id
  }
}

# Criação do IP público do nó mestre
resource "azurerm_public_ip" "swarm-master-pip" {
  name                = "swarm-master-pip"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Criação do IP público dos nós trabalhadores
resource "azurerm_public_ip" "swarm-node-pip" {
  count               = var.node_count
  name                = "swarm-node-pip-${count.index}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Criação da máquina virtual do nó mestre
resource "azurerm_linux_virtual_machine" "swarm_master" {
  name                  = "swarm-master-vm"
  location              = azurerm_resource_group.main.location
  resource_group_name   = azurerm_resource_group.main.name
  network_interface_ids = [azurerm_network_interface.swarm-master-nic.id]
  size                  = "Standard_B1s"
  admin_username        = "adminuser"

  disable_password_authentication = true

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("/home/pmacoy/.ssh/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 30
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
}

# Criação da máquina virtual dos nós trabalhadores
resource "azurerm_linux_virtual_machine" "swarm_node" {
  count                 = var.node_count
  name                  = "swarm-node-vm-${count.index}"
  location              = azurerm_resource_group.main.location
  resource_group_name   = azurerm_resource_group.main.name
  network_interface_ids = [azurerm_network_interface.swarm-node-nic[count.index].id]
  size                  = "Standard_B1s"
  admin_username        = "adminuser"

  disable_password_authentication = true

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("/home/pmacoy/.ssh/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 30
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
}

# Criação do serviço Docker Swarm
resource "docker_swarm_init" "swarm" {
  advertise_addr = format("%s", azurerm_public_ip.swarm-master-pip.ip_address)
  listen_addr    = "0.0.0.0:2377"
  force_create   = true
}

# Criação dos nós trabalhadores do Docker Swarm
resource "docker_swarm_node" "worker_node" {
  count      = var.node_count - 1
  join_token = docker_swarm_init.swarm.join_tokens[count.index]
}

# Criação do serviço Nginx
resource "docker_service" "nginx" {
  name     = "nginx"
  replicas = 2

  task_spec {
    restart_policy = "always"

    executor_resources {
      reservations {
        cpus   = "0.1"
        memory = "512Mi"
      }
    }

    network_mode = "overlay"

    resources {
      reservations {
        devices = [
          {
            driver = "local"
            driver_opts = {
              path = "/dev/shm"
              size = "100Mi"
            }
          }
        ]
      }
    }

    container_spec {
      image = var.nginx_image
      ports = [
        {
          target    = 80
          published = 80
        }
      ]

      volumes = [
        {
          name       = "php-volume"
          mount_path = "/var/www/html"
        }
      ]
    }
  }
}

# Criação do serviço SQL Server
resource "docker_service" "sqlserver" {
  name     = "sqlserver"
  replicas = 1

  task_spec {
    restart_policy = "always"

    executor_resources {
      reservations {
        cpus   = "0.5"
        memory = "1Gi"
      }
    }

    network_mode = "overlay"

    resources {
      reservations {
        devices = [
          {
            driver = "local"
            driver_opts = {
              path = "/var/lib/mssql/data"
              size = "10Gi"
            }
          }
        ]
      }
    }

    container_spec {
      image = var.sql_server_image
      environment = {
        ACCEPT_EULA = "Y"
        SA_PASSWORD = var.sql_password
        MSSQL_PID   = "Express"
      }
    }
  }
}

# Criação do volume PHP
resource "docker_volume" "php_volume" {
  name   = var.php_volume_name
  driver = "local"
  driver_opts = {
    o    = "bind"
    type = "none"
  }
}

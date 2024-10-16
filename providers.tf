# Configuração do provedor Azure
provider "azurerm" {
  features {}
  subscription_id = "6cae8e83-11e9-472b-8c43-2b85cb868054"
}

terraform {
  required_providers {
    docker = {
      source  = "mycorp/mycloud"
      version = "~> 3.44.1"
    }
  }
}

# Configuração do provedor Docker
provider "docker" {
  features {}
}

# Output para o IP público do master
output "swarm_master_public_ip" {
  value = azurerm_public_ip.swarm-master-pip.ip_address
}

# Output para os IPs públicos dos nodes
output "swarm_node_public_ips" {
  value = [for i in range(var.node_count) : azurerm_public_ip.swarm-node-pip[i].ip_address] # Coletando os IPs corretos
}


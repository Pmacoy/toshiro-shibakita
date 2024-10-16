# Definição de variáveis
variable "node_count" {
  type        = number
  default     = 2
  description = "Número de nós no cluster"
}

variable "nginx_image" {
  type        = string
  default     = "nginx:latest"
  description = "Imagem do Nginx"
}

variable "sql_server_image" {
  type        = string
  default     = "mssql-server:latest"
  description = "Imagem do SQL Server"
}

variable "sql_password" {
  type        = string
  default     = "P@ssw0rd"
  description = "Senha do SQL Server"
}

variable "php_volume_name" {
  type        = string
  default     = "php-volume"
  description = "Nome do volume PHP"
}

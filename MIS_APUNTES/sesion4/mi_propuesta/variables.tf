# variables.tf
variable "aws_region" {
  description = "Región de AWS donde se desplegarán los recursos"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefijo identificador para nombres de recursos en AWS"
  type        = string
  default     = "tfaws"
}

variable "vpc_cidr" {
  description = "Bloque CIDR para la VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnets_cidrs" {
  description = "Lista de bloques CIDR para subredes públicas"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnets_cidrs" {
  description = "Lista de bloques CIDR para subredes privadas"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24"]
}

variable "key_name" {
  description = "Nombre de la key pair de EC2 para SSH"
  type        = string
  default     = ""
}

variable "instance_type" {
  description = "Tipo de instancia EC2 para los servidores web"
  type        = string
  default     = "t3.micro"
}

# --- Nuevas variables para Secrets Manager ---
variable "db_user" {
  description = "Usuario de la base de datos"
  type        = string
}

variable "db_pass" {
  description = "Contraseña de la base de datos"
  type        = string
}

variable "tomcat_user" {
  description = "Usuario admin de Tomcat"
  type        = string
}

variable "tomcat_pass" {
  description = "Contraseña admin de Tomcat"
  type        = string
}

variable "hmac_sha_key" {
  description = "Token HMAC-SHA256 de 32 caracteres para firma de tokens de la aplicación"
  type        = string
}

# --- Variables para Certificado y Reglas ---
variable "domain_name" {
  description = "Dominio para el certificado ACM"
  type        = string
}

variable "admin_ip" {
  description = "IP externa para acceso directo al RDS"
  type        = string
}
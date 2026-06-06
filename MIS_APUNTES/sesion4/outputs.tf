# outputs.tf

data "aws_secretsmanager_secret_version" "current_secrets" {
  secret_id  = aws_secretsmanager_secret.app_secrets.id
  depends_on = [aws_secretsmanager_secret_version.app_secrets_val]
}

output "alb_url" {
  description = "URL para acceder a la aplicación Tomcat vía HTTPS"
  value       = "https://${aws_lb.app_lb.dns_name}"
}

output "rds_endpoint" {
  description = "Endpoint (DNS) de la base de datos RDS"
  value       = aws_db_instance.app_db.address
}

output "secret_db_credentials" {
  description = "Credenciales de Base de Datos recuperadas del Secret Manager"
  value       = "User: ${jsondecode(data.aws_secretsmanager_secret_version.current_secrets.secret_string)["db_user"]} | Pass: ${jsondecode(data.aws_secretsmanager_secret_version.current_secrets.secret_string)["db_pass"]}"
  sensitive   = true 
}

output "secret_tomcat_credentials" {
  description = "Credenciales de Tomcat recuperadas del Secret Manager"
  value       = "User: ${jsondecode(data.aws_secretsmanager_secret_version.current_secrets.secret_string)["tomcat_user"]} | Pass: ${jsondecode(data.aws_secretsmanager_secret_version.current_secrets.secret_string)["tomcat_pass"]}"
  sensitive   = true
}


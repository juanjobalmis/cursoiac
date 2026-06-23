# seguridad.tf
# aws_security_group para el ALB, servidores web, base de datos y EFS
resource "aws_security_group" "alb_sg" {
  name        = "${var.project_name}-alb-sg"
  description = "Permitir HTTP/HTTPS desde Internet al ALB"
  vpc_id      = aws_vpc.main_vpc.id

  # Permitir tráfico HTTP (80) y HTTPS (443) desde cualquier lugar
  # Deberíamos quitar el acceso HTTP en producción y solo permitir HTTPS, pero lo dejamos para pruebas
  ingress {
    description = "HTTP desde Internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # NUEVO: Permitir tráfico HTTPS (443) desde cualquier lugar
  ingress {
    description = "HTTPS desde Internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }
  tags = { Name = "${var.project_name}-alb-sg" }
}

resource "aws_security_group" "web_sg" {
  name        = "${var.project_name}-web-sg"
  description = "Permitir acceso al servidor web desde ALB"
  vpc_id      = aws_vpc.main_vpc.id

  ingress {
    description     = "HTTP desde el ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }
  tags = { Name = "${var.project_name}-web-sg" }
}

resource "aws_security_group" "db_sg" {
  name        = "${var.project_name}-db-sg"
  description = "Permitir acceso MySQL desde servidores web"
  vpc_id      = aws_vpc.main_vpc.id

  ingress {
    description     = "MySQL desde Web SG"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.web_sg.id]
  }

  # NUEVO: Permite conexión MySQL desde la IP del administrador (opcional, para administración directa)
  # Esto es útil para acceder a la base de datos desde una herramienta de administración como MySQL Workbench
  ingress {
    description = "Acceso admin desde IP externa"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [var.admin_ip]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "${var.project_name}-db-sg" }
}


# Security Group para EFS
# Permitir tráfico NFS (2049) desde los servidores web
# Esto es necesario para que los servidores web puedan montar el sistema de archivos EFS
resource "aws_security_group" "efs_sg" {
  name        = "${var.project_name}-efs-sg"
  description = "Permitir acceso NFS (EFS) desde servidores web"
  vpc_id      = aws_vpc.main_vpc.id
  
  ingress {
    description     = "NFS desde Web SG"
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.web_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "${var.project_name}-efs-sg" }
}
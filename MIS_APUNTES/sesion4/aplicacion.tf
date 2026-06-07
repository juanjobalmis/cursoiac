# aplicacion.tf

# --- 1. EFS ---
# Creamos un sistema de archivos EFS y sus puntos de montaje en cada subred privada 
# para que los servidores web puedan compartir datos persistentes (logs, uploads, etc.) entre ellos.
resource "aws_efs_file_system" "shared_fs" {
  provisioned_throughput_in_mibps = 0
  throughput_mode                 = "bursting"
  encrypted                       = false
  tags = { Name = "${var.project_name}-efs" }
}

# Creamos un punto de montaje en cada subred privada para que los 
# servidores web puedan montar el sistema de archivos EFS
resource "aws_efs_mount_target" "efs_mount" {
  count           = length(var.private_subnets_cidrs)
  file_system_id  = aws_efs_file_system.shared_fs.id
  subnet_id       = aws_subnet.private[count.index].id
  security_groups = [aws_security_group.efs_sg.id]
}

# --- 2. Secrets Manager ---
# NUEVO: Creamos un secreto en AWS Secrets Manager para almacenar de forma segura las credenciales de la base de datos y Tomcat.
resource "aws_secretsmanager_secret" "app_secrets" {
  name        = "${var.project_name}-app-credentials"
  description = "Credenciales para RDS y Tomcat"
}

resource "aws_secretsmanager_secret_version" "app_secrets_val" {
  secret_id     = aws_secretsmanager_secret.app_secrets.id
  secret_string = jsonencode({
    db_user          = var.db_user
    db_pass          = var.db_pass
    tomcat_user      = var.tomcat_user
    tomcat_pass      = var.tomcat_pass
    hmacSHA256_token = var.hmacSHA256_token
  })
}

# --- 3. RDS ---
resource "aws_db_subnet_group" "rds_subnets" {
  name       = "${var.project_name}-rds-subnetgrp"
  subnet_ids = aws_subnet.private[*].id
  tags = { Name = "${var.project_name}-rds-subnetgrp" }
}

resource "aws_db_instance" "app_db" {
  identifier             = "${var.project_name}-db"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  db_name                = "appdb" 

  # NUEVO: En lugar de hardcodear el usuario y contraseña, los obtenemos del secreto de Secrets Manager
  username               = jsondecode(aws_secretsmanager_secret_version.app_secrets_val.secret_string)["db_user"]
  password               = jsondecode(aws_secretsmanager_secret_version.app_secrets_val.secret_string)["db_pass"]
  
  db_subnet_group_name   = aws_db_subnet_group.rds_subnets.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  publicly_accessible    = false
  skip_final_snapshot    = true
  deletion_protection    = false
  tags = { Name = "${var.project_name}-db" }

  depends_on = [aws_secretsmanager_secret_version.app_secrets_val]
}

# --- 4. ALB y ACM ---
# NUEVO: Creamos un certificado SSL con ACM para el dominio que usaremos en el ALB, 
# y configuramos el listener HTTPS para usar este certificado.
# IMPORTANTE: Este certificado quedará en estado "Pending validation" hasta que se complete 
# la validación DNS, lo cual es un paso manual que debes realizar en tu proveedor de DNS.
# 1. Validar el certificado SSL/TLS de AWS
#    Una vez que Terraform termine, ve a la consola web de AWS, busca Certificate Manager (ACM)
#    y entra en el certificado de tu dominio.
#    AWS te mostrará un Nombre de CNAME y un Valor de CNAME (algo como _xxyyzz.midemo.com apuntando a _aabbcc.acm-validations.aws).
#    Tienes que ir a la gestión de DNS de tu proveedor y crear ese registro CNAME exacto. 
#    AWS lo detectará pasados unos minutos y cambiará el estado del certificado a Issued (Emitido).
# 2. Apuntar tu dominio en tu proveedor al ALB de AWS
#    Terraform te devolverá en la terminal un output llamado alb_url 
#    (por ejemplo: tfaws-alb-123456.us-east-1.elb.amazonaws.com).
#    Tienes que ir a tu proveedor y crear otro registro CNAME para que tu dominio 
#   (ej. www.midemo.com o app.midemo.com) apunte a esa URL larguísima del ALB.
resource "aws_acm_certificate" "alb_cert" {
  domain_name       = var.domain_name
  validation_method = "DNS"
  tags = { Name = "${var.project_name}-cert" }
}

# Nota: Como estás validando el DNS de forma manual en tu proveedor,
# este recurso se quedará "esperando" en la terminal hasta que crees el CNAME.
resource "aws_acm_certificate_validation" "cert_validation" {
  certificate_arn = aws_acm_certificate.alb_cert.arn
}

# Definimos el recurso de validación DNS para ACM
resource "aws_lb" "app_lb" {
  name                       = "${var.project_name}-alb"
  load_balancer_type         = "application"
  subnets                    = aws_subnet.public[*].id
  security_groups            = [aws_security_group.alb_sg.id]
  idle_timeout               = 60
  enable_deletion_protection = false
  tags = { Name = "${var.project_name}-alb" }
}

# No sé que hace este recurso aquí, lo dejo comentado
# Según la IA esto es para validar el certificado ACM
resource "aws_lb_target_group" "web_tg" {
  name        = "${var.project_name}-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main_vpc.id
  target_type = "instance"
  health_check {
    path                = "/"
    protocol            = "HTTP"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }
}

# NUEVO: Listener para HTTP que redirige a HTTPS
resource "aws_lb_listener" "alb_listener_http" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# NUEVO: Listener para HTTPS usando el certificado ACM
resource "aws_lb_listener" "alb_listener_https" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  
  # Seguimos usando el ARN del certificado...
  certificate_arn   = aws_acm_certificate.alb_cert.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_tg.arn
  }

  # ¡CLAVE!: Obligamos al Listener a esperar a que la validación termine con éxito
  depends_on = [aws_acm_certificate_validation.cert_validation]
}

# --- 5. EC2 e Inicialización ---
data "aws_ssm_parameter" "amzn2" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_launch_template" "web_lt" {
  name_prefix            = "${var.project_name}-lt-"
  image_id               = data.aws_ssm_parameter.amzn2.value
  instance_type          = var.instance_type
  key_name               = var.key_name != "" ? var.key_name : null
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  
  iam_instance_profile {
    name = "LabInstanceProfile" 
  }

  # NUEVO: En lugar de usar un script de userdata simple, ahora usamos un template file 
  # que nos permite pasar variables dinámicas (como el ID del EFS, la dirección de la base de datos, 
  # el ARN del secreto, etc.) al script de inicialización de los servidores web.
  user_data = base64encode(templatefile("${path.module}/userdata/staging-web.sh", {
    efs_id     = aws_efs_file_system.shared_fs.id
    region     = var.aws_region
    db_host    = aws_db_instance.app_db.address
    secret_arn = aws_secretsmanager_secret.app_secrets.arn
  }))

  tag_specifications {
    resource_type = "instance"
    tags = { Name = "${var.project_name}-web" }
  }
}

resource "aws_autoscaling_group" "web_asg" {
  name_prefix         = "${var.project_name}-asg-"
  launch_template {
    id      = aws_launch_template.web_lt.id
    version = "$Latest"
  }
  vpc_zone_identifier       = aws_subnet.private[*].id
  target_group_arns         = [aws_lb_target_group.web_tg.arn]
  desired_capacity          = 2
  min_size                  = 1
  max_size                  = 2
  health_check_type         = "EC2"
  health_check_grace_period = 90

  tag {
    key                 = "Name"
    value               = "${var.project_name}-tomcat"
    propagate_at_launch = true
  }

  # IMPORTANTE: El ASG debe esperar a que el EFS esté listo y 
  # montado antes de lanzar las instancias, para evitar errores en el 
  # arranque de Tomcat y condiciones de carrera. Por eso usamos depends_on aquí.
  depends_on = [aws_efs_mount_target.efs_mount]
}
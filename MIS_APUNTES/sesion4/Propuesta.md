# Ejemplo de de arquitectura a desplegar

Se propone para la arquitectura un diagrama similar al siguiente:

```puml { align=center }
@startuml

' https://awslabs.github.io/aws-icons-for-plantuml/

!define AWSPuml https://raw.githubusercontent.com/awslabs/aws-icons-for-plantuml/v23.0/dist

!include AWSPuml/AWSCommon.puml
!include AWSPuml/AWSSimplified.puml
!include AWSPuml/Groups/AWSCloud.puml
!include AWSPuml/Groups/VPC.puml
!include AWSPuml/Groups/AvailabilityZone.puml
!include AWSPuml/Groups/PublicSubnet.puml
!include AWSPuml/Groups/PrivateSubnet.puml
!include AWSPuml/Groups/AutoScalingGroup.puml
!include AWSPuml/NetworkingContentDelivery/VPCNATGateway.puml
!include AWSPuml/NetworkingContentDelivery/VPCInternetGateway.puml
!include AWSPuml/NetworkingContentDelivery/ElasticLoadBalancingApplicationLoadBalancer.puml
!include AWSPuml/Database/AuroraMySQLInstance.puml
!include AWSPuml/Compute/EC2Instance.puml
!include AWSPuml/Storage/EFS.puml
!include AWSPuml/ManagementGovernance/CloudFormationTemplate.puml

hide stereotype
scale 600 width
left to right direction
' skinparam linetype ortho

AWSCloudGroup(cloud) {

    VPCInternetGateway(igw, "Internet\nGateway", "")

    VPCGroup(vpc) {

        ElasticLoadBalancingApplicationLoadBalancer(alb, "Balanceador\nde carga (ALB)", "")

        AvailabilityZoneGroup(az_1b, "AZ us-east-1b") {
          PublicSubnetGroup(pub_b, "Subred pública\ren zona b") #ivory {
                VPCNATGateway(nat_gateway_b, "NAT\nGateway", "")  #transparent
            }
            PrivateSubnetGroup(priv_b, "Subred privada\r en zona b") #azure {
                AuroraMySQLInstance(rds_b, "RDS\nMySQL", "")  #transparent
                EC2Instance(ec2_b, "Instancia T3\ncon\nWordpress", "") #transparent
            }
        }          

        AvailabilityZoneGroup(az_1a, "AZ us-east-1a") {            
            PublicSubnetGroup(pub_a, "Subred pública\ren zona a") #ivory {
                VPCNATGateway(nat_gateway_a, "NAT\nGateway", "")  #transparent
            }
            PrivateSubnetGroup(priv_a, "Subred privada\ren zona a") #azure {
                    AuroraMySQLInstance(rds_a, "RDS\nMySQL", "")  #transparent
                    AutoScalingGroupGroup(asg_a, "AutoScaling") #transparent {
                        EC2Instance(ec2_a, "Instancia T3\ncon\nWordpress", "") #transparent
                    }
            }
        }
    }

    EFS(efs, "Elastic File\nSystem", "")
    CloudFormationTemplate(launchTemplate, "Launch Template\ncon user data", "")

    igw <--> alb
    igw --> nat_gateway_a
    igw --> nat_gateway_b
    alb <--> ec2_a
    alb <--> ec2_b
    nat_gateway_a --> ec2_a
    nat_gateway_b --> ec2_b
    ec2_a <--> rds_a
    ec2_b <--> rds_b

    launchTemplate --> asg_a
    efs --> ec2_a
}

@enduml
```

## Introducción al proyecto de Terraform para desplegar en AWS

Ver **`sesiones_3_4_terraform/practica-terraform-aws/Readme.md`** [text](../../sesiones_3_4_terraform/practica-terraform-aws/Readme.md).

Tendremos la siguiente estructura de archivos para el proyecto:

```bash
$ tree
.
├── seguridad.tf
├── red.tf
├── aplicacion.tf
├── outputs.tf
├── providers.tf
├── variables.tf
└── userdata
    └── staging-web.sh
```

## Dependencias entre recursos en Terraform

Cuando ejecutamos un **`terraform init`**. **¿Cómo sabe Terraform que archivos debe leer?**. Fíjate que en muchos **`resouces`** hay un bloque **`depends_on`**. Esto indica que el recurso depende de otro. De esta manera, Terraform puede construir un grafo de dependencias entre los recursos y determinar el orden correcto para crearlos. Por ejemplo, si un recurso A depende de un recurso B, Terraform se asegurará de crear primero el recurso B antes de crear el recurso A.

## Opciones para gestionar credenciales de AWS en Terraform

Aunque muchas credenciales están hardcodeadas en **`variables.tf`** , podríamos usar un archivo **`terraform.tfvars`** para almacenar valores específicos de nuestro entorno, como las credenciales de AWS, y luego referenciar ese archivo en nuestro comando de Terraform. Esto nos permite mantener nuestras credenciales fuera del código fuente y facilita la gestión de diferentes entornos (desarrollo, staging, producción) con diferentes configuraciones. Este archivo **no debe ser incluido en el control de versiones para evitar exponer información sensible**. En su lugar, se puede agregar a **`.gitignore`**.

Otra opción más profesional es usar un **servicio de gestión de secretos**, como **`AWS Secrets Manager`**, para almacenar y gestionar nuestras credenciales de forma segura. Terraform tiene un proveedor para AWS Secrets Manager que nos permite recuperar las credenciales directamente desde el servicio durante la ejecución de Terraform, evitando así la necesidad de almacenar credenciales en archivos locales.

Para crear este **servicio de gestión de secretos** en AWS, podemos usar el siguiente bloque de código en Terraform:

```groovy
resource "aws_secretsmanager_secret" "db_credentials" {
  name        = "db_credentials"
  description = "Credenciales para la base de datos RDS"
}

resource "aws_secretsmanager_secret_version" "db_credentials_version" {
  secret_id     = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = var.db_username
    password = var.db_password
  })
}
```

Fíjate que aún seguimos usando las variables **`db_username`** y **`db_password`** para almacenar las credenciales, pero estas variables ahora solo se usan para crear el secreto en AWS Secrets Manager. Luego, en lugar de referenciar directamente estas variables en nuestros recursos de RDS, podemos usar el bloque **`data "aws_secretsmanager_secret_version"`** para recuperar las credenciales desde Secrets Manager durante la ejecución de Terraform. Esto mejora la seguridad al evitar que las credenciales estén presentes en los archivos de configuración de Terraform o en el estado de Terraform.

## Grupos de seguridad encadenados

```puml { align=center }
@startuml

' https://awslabs.github.io/aws-icons-for-plantuml/

!define AWSPuml https://raw.githubusercontent.com/awslabs/aws-icons-for-plantuml/v23.0/dist

!include AWSPuml/AWSCommon.puml
!include AWSPuml/AWSSimplified.puml
!include AWSPuml/Groups/AWSCloud.puml
!include AWSPuml/Groups/VPC.puml
!include AWSPuml/Groups/PublicSubnet.puml
!include AWSPuml/Groups/PrivateSubnet.puml
!include AWSPuml/NetworkingContentDelivery/VPCInternetGateway.puml

hide stereotype
scale 600 width
left to right direction
' skinparam linetype ortho

AWSCloudGroup(cloud) {

    VPCInternetGateway(igw, "Internet\nGateway", "")

    VPCGroup(vpc) {
        PublicSubnetGroup(pub_a, "Subred pública") #ivory {
            rectangle "Grupo de seguridad\nbalanceador de carga\nALB" as gs_alb #transparent;line:orange;text:orange;
        }
        PrivateSubnetGroup(priv_a, "Subred privada") #azure {
            rectangle "Grupo de seguridad\nservidor EC2" as gs_ec2 #transparent;line:orange;text:orange;
            rectangle "Grupo de seguridad\nbase de datos" as gs_rds #transparent;line:orange;text:orange;
            rectangle "Grupo de seguridad\nEFS" as gs_efs #transparent;line:orange;text:orange;
        }
    }

    igw --> gs_alb
    gs_alb --> gs_ec2 : encadena
    gs_ec2 --> gs_rds : encadena
    gs_ec2 --> gs_efs: encadena
}

@enduml
```

Si quisiera acceder desde la IP de mi casa a la base de datos RDS, no podría hacerlo directamente con WorkBench porque el grupo de seguridad de RDS solo permite tráfico desde el grupo de seguridad del servidor EC2. Pero podría añadir una regla al grupo de seguridad del RDS para permitir tráfico desde mi IP.

## Preparación de la EC2 T3.micro

Tendré dos opciones:

1. Preparar una AMI personalizada con todo lo necesario para ejecutar Wordpress, y luego usar esa AMI en el bloque **`aws_launch_template`** de Terraform. Esto me permitiría tener una imagen preconfigurada que se puede lanzar rápidamente, pero requeriría un esfuerzo inicial para crear y mantener la AMI.
2. Usar stage scripts (user data) para configurar la instancia EC2 en el momento del lanzamiento. Esto me permitiría mantener una configuración más dinámica y flexible, pero podría aumentar el tiempo de arranque de la instancia debido a la necesidad de ejecutar los scripts cada vez que se lanza una nueva instancia.

## Qué es Cluod Front y cómo se relaciona con el balanceador de carga ALB

**CloudFront** es un servicio de red de entrega de contenido (CDN) de AWS que se utiliza para distribuir contenido a los usuarios finales con baja latencia y alta velocidad de transferencia. CloudFront se integra con otros servicios de AWS, como S3, EC2, ALB, entre otros, para entregar contenido de manera eficiente. En el contexto de un balanceador de carga ALB, CloudFront puede actuar como una capa adicional de distribución de contenido, permitiendo que el tráfico se dirija al ALB desde ubicaciones geográficamente dispersas, mejorando así la experiencia del usuario al reducir la latencia y aumentar la velocidad de entrega del contenido. Además, CloudFront ofrece características de seguridad adicionales, como protección contra ataques DDoS, lo que puede ayudar a proteger el ALB y los recursos detrás de él.


Los 2 pasos manuales que tendrás que hacer en Strato
Para que todo el ecosistema funcione de principio a fin, tendrás que entrar al panel de control de Strato y hacer lo siguiente:

1. Validar el certificado SSL/TLS de AWS

Una vez que Terraform termine, ve a la consola web de AWS, busca Certificate Manager (ACM) y entra en el certificado de tu dominio.

AWS te mostrará un Nombre de CNAME y un Valor de CNAME (algo como _xxyyzz.midemo.com apuntando a _aabbcc.acm-validations.aws).

Tienes que ir a la gestión de DNS de Strato y crear ese registro CNAME exacto. AWS lo detectará pasados unos minutos y cambiará el estado del certificado a Issued (Emitido).

2. Apuntar tu dominio de Strato al ALB de AWS

Terraform te devolverá en la terminal un output llamado alb_url (por ejemplo: tfaws-alb-123456.us-east-1.elb.amazonaws.com).

Tienes que ir a Strato y crear otro registro CNAME para que tu dominio (ej. www.midemo.com o app.midemo.com) apunte a esa URL larguísima del ALB.

![alt text](image.png)
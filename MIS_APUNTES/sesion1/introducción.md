# Introducción

## Laboratorio de AWS

Al acabar las 4h el laboratorio se apaga pero la infraestructura se apaga pero no se destruye, por lo que si quieres volver a acceder a la infraestructura después de que el laboratorio se haya apagado, puedes volver a encenderlo desde la pestaña "My Lab" y luego pulsar en "Start Lab".

Tienes 50$ de crédito para gastar en AWS durante el laboratorio. Si se gasta el crédito se apaga el laboratorio.

## Credenciales del laboratorio

En el laboratorio en la pestaña "i AWS Details" se encuentran las credenciales para acceder a la consola de AWS. Estas credenciales son temporales y solo estarán disponibles durante el tiempo que dure el laboratorio.

En "AWS CLI" se encuentran las credenciales para acceder a AWS a través de la línea de comandos. 

 Por ejemplo, si pulsamos en "AWS CLI" se nos mostrará un bloque de texto con las credenciales necesarias para configurar la AWS CLI. Estas credenciales incluyen el `aws_access_key_id`, `aws_secret_access_key` y `aws_session_token`.

``` txt
[default]
aws_access_key_id=ASIAS47IYKXW7NUIB6RE

aws_secret_access_key=2iLOMH7AuAit45XUE/92d0OXoDLthnb30+G3eah3

aws_session_token=IQoJb3JpZ2luX2VjED8aCXVzLXdlc3QtMiJHMEUCIAhUwqAXJQvzqdQqIXzizvnsE+2s9D2BcxcuKEB6Tm5dAiEAo1WTrZx+CMNCr/JrekZ8FCAvmwTlnEVUcf9lZpEb2csqtQIICBABGgwxOTk2NjcyNDI0NzciDISSjWknJcDiCpwFqCqSAm40tTKsKVdiZYZqjZRODb61xn2jY9kO98i6yg3qOINfPVHVkzItBUcNuRACS9DtgWx82i2/2CDbELRiImz9XoTB2pGEl3n0K+ic2nqEc/UZOvatYxKDwfjMJbKywHslgXmOIQ15RaynTsRP1TsT5qJN5DHqtBRFie6fck5WUSoHP6kpDaJey56fNKokC4jQCqtE2uoW4W+yLVXBQJqOvV/M0UxXUDSnT+0OFzACO1zJhwesNzb7N7akhjSCVJFiTfnFYNJS2nujaXyjsCYiEVAJUebelI0siddR/RyYp6X6Lo1fAFsJGHYZW3dR9HTCOXo/UNkhR7zuyXOj7MEL3S4T2sNMEl3Jx926mzMHDVyQXAIwtMv00AY6nQFN5HikYI4h2RGsCAT0l6pMtP06ltCfMVmaEczsFc3U12KRKGB6qMCavSJi8OzgAhX0G3COSe1uTl6mA/A31MZBgjzVVcxbmSAumWBnr6MiekhFszMhmJmrr/+6r2BnKBV4UGzIynhVUlgss2+qGjaUmDCenBNsOBvNRXcANtqYDql9bp7DmS+xEnfCMHvp751KY661pJHgk0XZBCug
```

## Servicios core

**VPCs**: Virtual Private Cloud, es una red virtual privada en la nube de AWS. Nos permite crear una red aislada dentro de la nube de AWS donde podemos lanzar recursos como instancias EC2, bases de datos RDS, etc. Podremos crear subredes, tablas de rutas, gateways de internet, etc. para configurar nuestra VPC.

* **Subnets**: Subredes dentro de una VPC. Nos permiten segmentar nuestra red en diferentes zonas de disponibilidad y controlar el tráfico entre ellas.

* Definimos un **CIDR** **general para la VPC por ejemplo `10.1.0.0/16`**, que nos da un rango de IPs disponibles para nuestra VPC. Luego podemos crear subredes dentro de ese rango, por ejemplo.
* `10.1.1.0/24` para la subred pública por ejemplo
* `10.1.2.0/24` para la subred privada por ejemplo

**Internet Gateway**: Es un gateway que permite la comunicación entre nuestra VPC y el internet. Me dará salida a internet para las instancias que estén en subredes públicas.

**Subred Pública**: Es una subred que tiene una ruta hacia el Internet Gateway, lo que permite que las instancias dentro de esa subred tengan acceso a internet.

**Subred Privada**: Es una subred que no tiene una ruta hacia el Internet Gateway, lo que significa que las instancias dentro de esa subred no tienen acceso directo a internet. Para que las instancias en la subred privada puedan acceder a internet, necesitamos configurar un **NAT Instance** en la subred pública.

**NAT Gateway**: Es un servicio gestionado por AWS que permite a las instancias en una subred privada acceder a internet sin exponer sus direcciones IP privadas. El NAT Gateway se coloca en una subred pública y se configura para enrutar el tráfico de salida desde la subred privada hacia internet. Tiene un **coste asociado**.

**Network ACLs**: Son listas de control de acceso a nivel de subred que permiten o deniegan el tráfico hacia y desde las subredes. Se aplican a todo el tráfico que entra o sale de una subred. Son firewalls sin estado (**stateless**).
Se evalúan las reglas en el orden en que están definidas. Si una regla coincide con el tráfico, se aplica esa regla y **se detiene la evaluación de las siguientes reglas**. Si ninguna regla coincide, se aplica la regla por defecto (que suele ser **denegar todo el tráfico**).

**Regiones y Zonas de Disponibilidad**: AWS tiene múltiples regiones geográficas, cada una con varias zonas de disponibilidad (AZ) entre 3 y 6. Las AZ son centros de datos físicamente separados dentro de una región. Al distribuir nuestros recursos entre diferentes AZ, podemos mejorar la disponibilidad y tolerancia a fallos de nuestras aplicaciones. Cada AZ tiene su propio conjunto de recursos, como energía, refrigeración y red, lo que ayuda a garantizar que si una AZ falla, las otras AZ en la misma región no se vean afectadas.

!!! Tip Importante
    Una VPC se puede extender a varias AZ, lo que nos permite crear subredes en diferentes AZ para mejorar la disponibilidad de nuestras aplicaciones. Por ejemplo, podríamos tener una **subred pública en AZ1** y otra **subred pública en AZ2**, y luego lanzar instancias EC2 en ambas subredes para garantizar que nuestras aplicaciones sigan funcionando incluso si una AZ falla. **Una subred no puede extenderse a varias AZ, cada subred debe estar asociada a una sola AZ**.

Es posible tener un solo NAT Gateway para todas las AZ, pero esto puede crear un punto único de fallo. Si el NAT Gateway falla, las instancias en la subred privada perderán su acceso a internet. Para mejorar la disponibilidad, **es recomendable tener un NAT Gateway en cada AZ** y configurar las tablas de rutas para que el tráfico de salida desde la subred privada se enrute al NAT Gateway correspondiente en cada AZ.

**EC2**: **Elastic Compute Cloud**, es un servicio que permite lanzar instancias de máquinas virtuales en la nube de AWS. Podemos elegir entre diferentes tipos de instancias (**T3.small**, etc.) según nuestras necesidades de CPU, memoria, almacenamiento, etc.

**T**: Signinifica que es una instancia de uso general.
**3**: Generación de la instancia, en este caso la tercera generación de instancias T.
**small**: Tamaño de la instancia

* **AMI**: **Amazon Machine Image**, es una plantilla que contiene la información necesaria para lanzar una instancia EC2. Incluye **el sistema operativo, las aplicaciones preinstaladas, las configuraciones de red, etc**. Podemos elegir entre AMIs proporcionadas por AWS, AMIs de la comunidad o crear **nuestras propias AMIs personalizadas**.

* **Grupo de Seguridad**: Es un firewall virtual que controla el tráfico hacia y desde las instancias EC2. Se aplica a nivel de instancia y permite definir reglas de entrada y salida para controlar el tráfico. Las reglas se basan en protocolos, puertos y direcciones IP de origen o destino.

    Las reglas de un grupo de seguridad son **stateful**, lo que significa que **si permitimos el tráfico de entrada en un puerto específico, el tráfico de salida correspondiente a esa conexión también estará permitido automáticamente**, sin necesidad de definir una regla de salida explícita para ese puerto.

* **EBS**: **Elastic Block Store**, es servicio de almacenamiento de HDD o SDD separado de una EC2 y que se puede adjuntar a la misma. Proporciona almacenamiento persistente para las instancias, lo que significa que los datos almacenados en un volumen EBS no se pierden cuando la instancia se detiene o termina. **Los volúmenes EBS están asociados a una AZ** y pueden ser de diferentes tipos, como **gp3 (General Purpose SSD)**, **io1 (Provisioned IOPS SSD)**, etc., cada uno con diferentes características de rendimiento y costo.

* **User Data**: Es un **script que se puede ejecutar automáticamente al iniciar una instancia EC2**.

* **IAM instance profile**: Es un **rol de IAM** que se puede asociar a una instancia EC2 para otorgarle **permisos específicos para acceder a otros servicios de AWS**. En un laboratorio será **`LabInstanceProfile`**, que tiene permisos para acceder a S3, CloudWatch, etc. **Un rol se puede asignar a un usuario, grupo o recurso de AWS, como una instancia EC2.**

* **Elastic IP**: Es una dirección IP estática que se puede asociar a una instancia EC2. Permite mantener la misma dirección IP incluso si la instancia se detiene o termina. Es **útil para aplicaciones que requieren una dirección IP fija**. También se puede asociar a un **NAT Gateway** para proporcionar una dirección IP pública fija para el tráfico de salida desde una subred privada.

* **EFS**: **Elastic File System**, es un **SERVICIO** de almacenamiento de archivos que **se puede montar en varias instancias EC2 simultáneamente**. Proporciona un sistema de archivos compartido y escalable que se puede utilizar para almacenar datos que necesitan ser accedidos por múltiples instancias EC2. Es útil para aplicaciones que requieren un sistema de archivos compartido, como servidores web, aplicaciones de análisis de datos, etc.

```puml {align=center}
@startuml VPC

' https://awslabs.github.io/aws-icons-for-plantuml/

!define AWSPuml https://raw.githubusercontent.com/awslabs/aws-icons-for-plantuml/v23.0/dist
!include AWSPuml/AWSCommon.puml
!include AWSPuml/AWSSimplified.puml
!include AWSPuml/Compute/EC2.puml
!include AWSPuml/Compute/EC2Instance.puml
!include AWSPuml/Groups/AWSCloud.puml
!include AWSPuml/Groups/VPC.puml
!include AWSPuml/Groups/AvailabilityZone.puml
!include AWSPuml/Groups/PublicSubnet.puml
!include AWSPuml/Groups/PrivateSubnet.puml
!include AWSPuml/NetworkingContentDelivery/VPCNATGateway.puml
!include AWSPuml/NetworkingContentDelivery/VPCInternetGateway.puml
!include AWSPuml/Database/AuroraMySQLInstance.puml
!include AWSPuml/Compute/EC2ElasticIPAddress.puml
!include AWSPuml/Storage/EFS.puml
!include AWSPuml/Storage/SimpleStorageServiceS3Standard.puml

hide stereotype
left to right direction
scale 500 width
skinparam linetype ortho

AWSCloudGroup(cloud) {
    VPCGroup(vpc) {
        VPCInternetGateway(internet_gateway, "Gateway entre\nInternet 0.0.0.0\nVPC 16.1.0.0/16", "")

        AvailabilityZoneGroup(az_1, "Zona de disponibilidad\nAZ1 en us-east-1") {

            PublicSubnetGroup(az_1_public, "Public 16.1.1.0/24") {
                VPCNATGateway(az_1_nat_gateway, "NAT", "") #Transparent
            }

            PrivateSubnetGroup(az_1_private, "Private 16.1.2.0/24") {
                AuroraMySQLInstance(az_1_mysql_1, "RDS", "") #Transparent
                EC2Instance(az_1_ec2_1, "EC2 T3.small", "") #Transparent

                az_1_mysql_1 <..> az_1_ec2_1
            }
        }

        az_1_mysql_1 ..> az_1_nat_gateway
        az_1_ec2_1 .u.> az_1_nat_gateway
        az_1_nat_gateway ..> internet_gateway
    }

    EFS(efs, "EFS", "") #Transparent   
    az_1_ec2_1 <..> efs
}
@enduml
```

**S3**: **Simple Storage Service**, es un servicio de almacenamiento de objetos que permite almacenar y recuperar cualquier cantidad de datos desde cualquier parte de la web. Es un servicio altamente escalable, duradero y seguro que se utiliza para almacenar datos como archivos, imágenes, videos, etc. Los objetos en S3 se organizan en **buckets**, que son contenedores lógicos para almacenar objetos. Cada bucket tiene un nombre único a nivel global y puede contener un número ilimitado de objetos. S3 también ofrece características como control de acceso, versionado, replicación, etc.

Para subir un archivo a S3 desde la línea de comandos, se puede usar el siguiente comando:

```bash
aws s3 cp my-file.txt s3://my-bucket/my-file.txt
```

Una ruta típica para acceder a un recurso sería: 

```bash
curl https://my-bucket.s3.amazonaws.com/my-file.txt
```

**RDS (Relational Database Service)**: Es un servicio gestionado de bases de datos relacionales que facilita la configuración, operación y escalado de bases de datos en la nube. RDS soporta varios motores de bases de datos, como MySQL, PostgreSQL, Oracle, SQL Server, etc. Proporciona características como copias de seguridad automáticas, recuperación ante desastres, escalado vertical y horizontal, etc.

* **Aurora**: Es un motor de base de datos relacional compatible con MySQL y PostgreSQL que ofrece un rendimiento y disponibilidad mejorados en comparación con las bases de datos tradicionales. **Aurora es parte de RDS** y proporciona características como replicación automática, recuperación ante desastres, escalado automático, etc. Al contrario que RDS, no se aprovisiona una EC2 gestionada por RDS, sino que ofrece una opción de base de datos serverless, lo que significa que no se necesita aprovisionar ni administrar servidores para ejecutar la base de datos. Aurora Serverless ajusta automáticamente la capacidad de la base de datos en función de la demanda, lo que permite un uso eficiente de los recursos y un costo optimizado.

## Servicios Serverless

Consumen muy poco a coste prácticamente 0 y se mide en GB-segundos, lo que significa que solo pagas por el tiempo de ejecución y la cantidad de recursos utilizados por tu función.

**Lambda**: Es un servicio de computación serverless que permite ejecutar código sin aprovisionar ni administrar servidores. Lambda ejecuta el código en respuesta a eventos, como cambios en datos, solicitudes HTTP, etc. El código se ejecuta en un entorno gestionado por AWS y se escala automáticamente según la demanda.

1:14
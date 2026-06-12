#!/bin/bash
# ==============================================================================
# SCRIPT DE INSTALACIÓN Y OPTIMIZACIÓN DE TOMCAT 11 CON JAVA 25 EN AWS EC2
# ==============================================================================
set -e

# Configuración de variables del entorno de ejecución de la instancia EC2
REGION="${region}"
EFS_ID="${efs_id}"
SECRET_ARN="${secret_arn}"
DB_HOST_PARAM="${db_host}"

# Actualización del sistema e instalación de dependencias requeridas
yum update -y
yum install -y jq amazon-efs-utils tar wget aws-cli

# ==============================================================================
# 1. INSTALACIÓN DE AMAZON CORRETTO 25 (JDK)
# ==============================================================================
# Descarga e instalación limpia de la distribución oficial de Corretto 25 LTS [cite: 35]
wget https://corretto.aws/downloads/latest/amazon-corretto-25-x64-linux-jdk.tar.gz -P /tmp/
mkdir -p /usr/local/corretto-25
tar -xzf /tmp/amazon-corretto-25-x64-linux-jdk.tar.gz -C /usr/local/corretto-25 --strip-components=1
rm -f /tmp/amazon-corretto-25-x64-linux-jdk.tar.gz

# Configuración y persistencia de variables de entorno globales del sistema
cat <<EOF > /etc/profile.d/java.sh
export JAVA_HOME=/usr/local/corretto-25
export PATH=/usr/local/corretto-25/bin:\$PATH
EOF
chmod 644 /etc/profile.d/java.sh

# ==============================================================================
# 2. INSTALACIÓN DE APACHE TOMCAT 11
# ==============================================================================
# Obtención de la distribución oficial y desempaquetado en el directorio de servicio [cite: 36, 37]
wget https://downloads.apache.org/tomcat/tomcat-11/v11.0.22/bin/apache-tomcat-11.0.22.tar.gz -P /tmp/
mkdir -p /opt/tomcat
tar -xzf /tmp/apache-tomcat-11.0.22.tar.gz -C /opt/tomcat --strip-components=1
rm -f /tmp/apache-tomcat-11.0.22.tar.gz

# Creación exclusiva del grupo y usuario del sistema sin privilegios de shell
groupadd -r tomcat
useradd -r -s /bin/false -g tomcat -d /opt/tomcat tomcat

# Configuración de permisos de aislamiento del sistema de archivos
chown -R tomcat:tomcat /opt/tomcat
chmod -R g+r /opt/tomcat/conf
chmod g+x /opt/tomcat/conf
chmod +x /opt/tomcat/bin/*.sh

# ==============================================================================
# 3. MONTAJE INTEGRADO DEL SISTEMA DE ARCHIVOS DISTRIBUIDO (AWS EFS)
# ==============================================================================
# Creación física del punto de montaje local de la aplicación
mkdir -p /opt/tomcat/webapps/ROOT/uploads

# Registro no volátil del montaje NFSv4.1 persistente con soporte _netdev [cite: 22, 24]
echo "${EFS_ID}.efs.${REGION}.amazonaws.com:/ /opt/tomcat/webapps/ROOT/uploads efs defaults,_netdev,noatime,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2 0 0" >> /etc/fstab

# Inicialización segura del montaje local mediante fstab [cite: 23, 25]
mount -a -t efs || mount /opt/tomcat/webapps/ROOT/uploads

# CORRECCIÓN DE SEGURIDAD CRÍTICA: Cambiar propietario del directorio DESPUÉS de montar EFS
chown -R tomcat:tomcat /opt/tomcat/webapps/ROOT/uploads
chmod 750 /opt/tomcat/webapps/ROOT/uploads

# ==============================================================================
# 4. CONFIGURACIÓN DE RED Y REDIRECCIÓN DE PUERTOS
# ==============================================================================
# Modificación de server.xml para escuchar directamente en el puerto privilegiado 80
sed -i 's/port="8080"/port="80"/g' /opt/tomcat/conf/server.xml

# NOTA ARQUITECTÓNICA: Se elimina el uso de 'setcap' del sistema de archivos para
# evitar la inhabilitación del cargador dinámico de libjli.so.
# La concesión de capacidades de enlace de red se delega de forma exclusiva a Systemd [cite: 8, 9].

# ==============================================================================
# 5. INTEGRACIÓN DE SECRETOS Y CONFIGURACIÓN XML DE TOMCAT
# ==============================================================================
# Obtención segura de las variables desde AWS Secrets Manager
SECRET_VAL=$(aws secretsmanager get-secret-value --secret-id "${SECRET_ARN}" --region "${REGION}" --query SecretString --output text)
DB_USER=$(echo "${SECRET_VAL}" | jq -r .db_user)
DB_PASS=$(echo "${SECRET_VAL}" | jq -r .db_pass)
TOMCAT_USER=$(echo "${SECRET_VAL}" | jq -r .tomcat_user)
TOMCAT_PASS=$(echo "${SECRET_VAL}" | jq -r .tomcat_pass)
HMAC_SHA_KEY=$(echo "${SECRET_VAL}" | jq -r .hmac_sha_key)

# Generación del archivo tomcat-users.xml alineado con el esquema formal de Tomcat 11
cat <<EOF > /opt/tomcat/conf/tomcat-users.xml
<?xml version="1.0" encoding="UTF-8"?>
<tomcat-users xmlns="http://tomcat.apache.org/xml"
              xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
              xsi:schemaLocation="http://tomcat.apache.org/xml tomcat-users.xsd"
              version="1.0">
  <role rolename="manager-gui"/>
  <role rolename="manager-script"/>
  <role rolename="admin-gui"/>
  <role rolename="admin-script"/>
  <user username="${TOMCAT_USER}" password="${TOMCAT_PASS}" roles="manager-gui,manager-script,admin-gui,admin-script"/>
</tomcat-users>
EOF
chown tomcat:tomcat /opt/tomcat/conf/tomcat-users.xml
chmod 600 /opt/tomcat/conf/tomcat-users.xml

# CORRECCIÓN DE ROBUSTEZ: Reemplazo lineal y predecible del filtro de acceso IP
# Esta modificación altera de forma segura el comportamiento predeterminado (RemoteAddrValve)
sed -i 's/allow="127\\.0\\.0\\.0\\/8,::1\\/128"/allow=".*"/g' /opt/tomcat/webapps/manager/META-INF/context.xml
sed -i 's/allow="127\.\\d+\\.\d+\\.\\d+|::1|0:0:0:0:0:0:0:1"/allow=".*"/g' /opt/tomcat/webapps/manager/META-INF/context.xml

# ==============================================================================
# 6. DEFINICIÓN DE LA UNIDAD DE SERVICIO SYSTEMD (TIPO SIMPLE)
# ==============================================================================
# Creación de la unidad del ciclo de vida bajo la estructura óptima de primer plano
cat <<EOF > /etc/systemd/system/tomcat.service
[Unit]
Description=Apache Tomcat 11 Web Application Container
After=network-online.target remote-fs.target
Wants=network-online.target
RequiresMountsFor=/opt/tomcat/webapps/ROOT/uploads

[Service]
# Monitoreo directo del hilo de ejecución de la JVM de Java
Type=simple

User=tomcat
Group=tomcat
RestartSec=10
Restart=always

# Definición de variables globales del entorno de runtime de Java
Environment="JAVA_HOME=/usr/local/corretto-25"
Environment="PATH=/usr/local/corretto-25/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin"
Environment="CATALINA_HOME=/opt/tomcat"
Environment="CATALINA_BASE=/opt/tomcat"
Environment="CATALINA_PID=/opt/tomcat/temp/tomcat.pid"

# Parámetros de ajuste de rendimiento de la máquina virtual de Java 25
Environment="JAVA_OPTS=-Djava.awt.headless=true -Djava.security.egd=file:/dev/./urandom"
Environment="CATALINA_OPTS=-Xms512M -Xmx1024M -server -XX:+UseG1GC"

# Variables de configuración del backend de la aplicación
Environment="HMAC_SHA_KEY=${HMAC_SHA_KEY}"
Environment="DB_HOST=${DB_HOST_PARAM}"
Environment="DB_USER=${DB_USER}"
Environment="DB_PASS=${DB_PASS}"

# Comando de arranque nativo que no bifurca el proceso de ejecución de Systemd
ExecStart=/opt/tomcat/bin/catalina.sh run

# Aislamiento y Concesión Segura de Capacidades a Nivel de Proceso
AmbientCapabilities=CAP_NET_BIND_SERVICE
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
SecureBits=keep-caps
PrivateTmp=true
NoNewPrivileges=true

# Código de terminación ordinaria del proceso Java ante señales del sistema
SuccessExitStatus=143

[Install]
WantedBy=multi-user.target
EOF

# Asignación de permisos correctos al archivo unitario del servicio de Systemd
chmod 644 /etc/systemd/system/tomcat.service

# ==============================================================================
# 7. INICIALIZACIÓN Y VALIDACIÓN DEL SISTEMA
# ==============================================================================
# Sincronización del demonio de Systemd para cargar la nueva configuración
systemctl daemon-reload

# Habilitación y arranque ordenado del servicio Tomcat
systemctl enable tomcat
systemctl start tomcat

echo "Aprovisionamiento y optimización de Apache Tomcat 11 y Java 25 completados con éxito."
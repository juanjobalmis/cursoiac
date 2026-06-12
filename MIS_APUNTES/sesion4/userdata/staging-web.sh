#!/bin/bash
set -e

# Instalar utilidades requeridas
yum update -y
yum install -y jq amazon-efs-utils tar wget aws-cli

# Instalación de Java 25 (Amazon Corretto 25)
# Descargamos el empaquetado oficial de Corretto 25
wget https://corretto.aws/downloads/latest/amazon-corretto-25-x64-linux-jdk.tar.gz -P /tmp/
mkdir -p /usr/local/corretto-25
tar -xzf /tmp/amazon-corretto-25-x64-linux-jdk.tar.gz -C /usr/local/corretto-25 --strip-components=1

# Configurar variables de entorno para Java
export JAVA_HOME=/usr/local/corretto-25
export PATH=$JAVA_HOME/bin:$PATH
echo "export JAVA_HOME=/usr/local/corretto-25" >> /etc/profile.d/java.sh
echo "export PATH=\$JAVA_HOME/bin:\$PATH" >> /etc/profile.d/java.sh

# Descargar e instalar Tomcat 11
wget https://downloads.apache.org/tomcat/tomcat-11/v11.0.22/bin/apache-tomcat-11.0.22.tar.gz
mkdir -p /opt/tomcat
tar -xzf apache-tomcat-11.0.22.tar.gz -C /opt/tomcat --strip-components=1

# Configurar usuario y permisos para Tomcat
groupadd tomcat
useradd -s /bin/false -g tomcat -d /opt/tomcat tomcat
chown -R tomcat: /opt/tomcat
sh -c 'chmod +x /opt/tomcat/bin/*.sh'

# Configurar EFS para Tomcat en /opt/tomcat/webapps/ROOT/uploads
mkdir -p /opt/tomcat/webapps/ROOT/uploads
mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport ${efs_id}.efs.${region}.amazonaws.com:/ /opt/tomcat/webapps/ROOT/uploads
echo '${efs_id}.efs.${region}.amazonaws.com:/ /opt/tomcat/webapps/ROOT/uploads efs defaults,_netdev 0 0' >> /etc/fstab

# Ajustar puerto Tomcat 8080 -> 80
sed -i 's/port="8080"/port="80"/g' /opt/tomcat/conf/server.xml

# Otorgar permisos al binario de Java para abrir puertos privilegiados (< 1024)
setcap cap_net_bind_service=+ep /usr/local/corretto-25/bin/java

# Recuperar Secretos de AWS Secrets Manager
# y configurar variables de entorno para la aplicación web con los valores recuperados
SECRET_VAL=$(aws secretsmanager get-secret-value --secret-id ${secret_arn} --region ${region} --query SecretString --output text)
DB_USER=$(echo $SECRET_VAL | jq -r .db_user)
DB_PASS=$(echo $SECRET_VAL | jq -r .db_pass)
TOMCAT_USER=$(echo $SECRET_VAL | jq -r .tomcat_user)
TOMCAT_PASS=$(echo $SECRET_VAL | jq -r .tomcat_pass)
HMAC_SHA_KEY=$(echo $SECRET_VAL | jq -r .hmac_sha_key)

# Configurar usuarios en Tomcat (usando el secreto recuperado)
cat <<EOF > /opt/tomcat/conf/tomcat-users.xml
<?xml version="1.0" encoding="UTF-8"?>
<tomcat-users>
  <role rolename="manager-gui"/>
  <role rolename="manager-script"/>
  <role rolename="admin-gui"/>
  <user username="$TOMCAT_USER" password="$TOMCAT_PASS" roles="admin,admin-gui,manager,manager-gui"/>
</tomcat-users>
EOF

# Permitir acceso al Manager de Tomcat desde cualquier IP (Adaptado a Tomcat 11)
sed -i '/<Valve className="org.apache.catalina.valves.RemoteCIDRValve"/,/allow="127\.0\.0\.0\/8,::1\/128" \/>/d' /opt/tomcat/webapps/manager/META-INF/context.xml

# 7. Servicio Systemd para Tomcat
cat <<EOF > /etc/systemd/system/tomcat.service
[Unit]
Description=Apache Tomcat 11
After=network.target

[Service]
Type=forking

User=tomcat
Group=tomcat
RestartSec=10
Restart=always

Environment="JAVA_HOME=/usr/local/corretto-25"
Environment="JAVA_OPTS=-Djava.awt.headless=true -Djava.security.egd=file:/dev/./urandom"
Environment="CATALINA_HOME=/opt/tomcat"
Environment="CATALINA_BASE=/opt/tomcat"
Environment="CATALINA_PID=/opt/tomcat/temp/tomcat.pid"
Environment="CATALINA_OPTS=-Xms512M -Xmx1024M -server -XX:+UseParallelGC"

# Variables de entorno para la aplicación web
Environment="HMAC_SHA_KEY=$HMAC_SHA_KEY"
Environment="DB_HOST=${db_host}"
Environment="DB_USER=$DB_USER"
Environment="DB_PASS=$DB_PASS"

# Ejecución
ExecStart=/opt/tomcat/bin/startup.sh
ExecStop=/opt/tomcat/bin/shutdown.sh

# Evitar que systemd marque el servicio como "fallido" al detener Java
SuccessExitStatus=143

[Install]
WantedBy=multi-user.target
EOF

# Configurar permisos para el servicio de Tomcat
chmod 664 /etc/systemd/system/tomcat.service

# Recargar systemd, iniciar y habilitar el servicio de Tomcat
systemctl daemon-reload
systemctl start tomcat
systemctl enable tomcat
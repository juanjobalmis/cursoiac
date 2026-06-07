#!/bin/bash
set -e

# 1. Instalar utilidades requeridas
yum update -y
yum install -y jq amazon-efs-utils tar wget aws-cli

# 2. Configurar la estructura de EFS para uploads compartidos
mkdir -p /opt/tomcat/webapps/ROOT/uploads

# Montar EFS
mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport ${efs_id}.efs.${region}.amazonaws.com:/ /opt/tomcat/webapps/ROOT/uploads

# Persistencia en fstab
echo '${efs_id}.efs.${region}.amazonaws.com:/ /opt/tomcat/webapps/ROOT/uploads efs defaults,_netdev 0 0' >> /etc/fstab

# 3. Instalación de Java 25 (Amazon Corretto 25)
# Descargamos el empaquetado oficial de Corretto 25
wget https://corretto.aws/downloads/latest/amazon-corretto-25-x64-linux-jdk.tar.gz -P /tmp/
mkdir -p /usr/local/corretto-25
tar -xzf /tmp/amazon-corretto-25-x64-linux-jdk.tar.gz -C /usr/local/corretto-25 --strip-components=1

export JAVA_HOME=/usr/local/corretto-25
export JRE_HOME=/usr/local/corretto-25
export PATH=$JAVA_HOME/bin:$PATH
echo "export JAVA_HOME=/usr/local/corretto-25" >> /etc/profile.d/java.sh
echo "export JRE_HOME=/usr/local/corretto-25" >> /etc/profile.d/java.sh
echo "export PATH=\$JAVA_HOME/bin:\$PATH" >> /etc/profile.d/java.sh

# 4. Instalación de Tomcat 11
useradd -m -U -d /opt/tomcat -s /bin/false tomcat
wget https://downloads.apache.org/tomcat/tomcat-11/v11.0.22/bin/apache-tomcat-11.0.22.tar.gz -P /tmp/
tar -xzf /tmp/apache-tomcat-11.0.22.tar.gz -C /opt/tomcat --strip-components=1

# Ajustar puerto Tomcat 8080 -> 80
sed -i 's/port="8080"/port="80"/g' /opt/tomcat/conf/server.xml

# Otorgar permisos al binario de Java para abrir puertos privilegiados (< 1024)
setcap cap_net_bind_service=+ep /usr/local/corretto-25/bin/java

# 5. Recuperar Secretos de AWS Secrets Manager
SECRET_VAL=$(aws secretsmanager get-secret-value --secret-id ${secret_arn} --region ${region} --query SecretString --output text)

# Usar JQ para extraer los valores del JSON
DB_USER=$(echo $SECRET_VAL | jq -r .db_user)
DB_PASS=$(echo $SECRET_VAL | jq -r .db_pass)
TOMCAT_USER=$(echo $SECRET_VAL | jq -r .tomcat_user)
TOMCAT_PASS=$(echo $SECRET_VAL | jq -r .tomcat_pass)
HMAC_SHA_KEY=$(echo $SECRET_VAL | jq -r .hmac_sha_key)

# 6. Configurar usuarios en Tomcat (usando el secreto recuperado)
cat <<EOF > /opt/tomcat/conf/tomcat-users.xml
<?xml version="1.0" encoding="UTF-8"?>
<tomcat-users>
  <role rolename="manager-gui"/>
  <role rolename="manager-script"/>
  <role rolename="admin-gui"/>
  <user username="$TOMCAT_USER" password="$TOMCAT_PASS" roles="manager-gui,manager-script,admin-gui"/>
</tomcat-users>
EOF

# Permitir acceso al Manager de Tomcat desde cualquier IP (Adaptado a Tomcat 11)
sed -i '/<Valve className="org.apache.catalina.valves.RemoteCIDRValve"/,/allow="127\.0\.0\.0\/8,::1\/128" \/>/d' /opt/tomcat/webapps/manager/META-INF/context.xml

# Otorgar permisos de la carpeta y EFS al usuario tomcat
chown -R tomcat:tomcat /opt/tomcat/
chmod -R u+x /opt/tomcat/bin
chmod -R 640 /opt/tomcat/conf/*
chmod 750 /opt/tomcat/conf/

# 7. Servicio Systemd para Tomcat
cat <<EOF > /etc/systemd/system/tomcat.service
[Unit]
Description=Apache Tomcat 11
After=network.target

[Service]
Type=forking
User=tomcat
Group=tomcat

# Configuración de Rutas y PID
Environment="JAVA_HOME=/usr/local/corretto-25"
Environment="JRE_HOME=/usr/local/corretto-25"
Environment="CATALINA_PID=/opt/tomcat/temp/tomcat.pid"
Environment="CATALINA_HOME=/opt/tomcat"
Environment="CATALINA_BASE=/opt/tomcat"
PIDFile=/opt/tomcat/temp/tomcat.pid

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

systemctl daemon-reload
systemctl start tomcat
systemctl enable tomcat
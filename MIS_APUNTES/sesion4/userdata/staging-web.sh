#!/bin/bash
# Actualización del sistema e instalación de dependencias requeridas
yum update -y
yum install -y jq amazon-efs-utils tar wget aws-cli

# ==============================================================================
# 1. INSTALACIÓN DE AMAZON CORRETTO 25 (JDK)
# ==============================================================================
# Descarga e instalación limpia de la distribución oficial de Corretto 25 LTS
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
# Obtención de la distribución oficial y desempaquetado en el directorio de servicio
wget https://downloads.apache.org/tomcat/tomcat-11/v11.0.22/bin/apache-tomcat-11.0.22.tar.gz -P /tmp/
mkdir -p /opt/tomcat
tar -xzf /tmp/apache-tomcat-11.0.22.tar.gz -C /opt/tomcat --strip-components=1
rm -f /tmp/apache-tomcat-11.0.22.tar.gz

# Creación exclusiva del grupo y usuario del sistema sin privilegios de shell
groupadd -r tomcat || true
useradd -r -s /bin/false -g tomcat -d /opt/tomcat tomcat || true
chown -R tomcat:tomcat /opt/tomcat
chmod +x /opt/tomcat/bin/*.sh

# ==============================================================================
# 3. MONTAJE INTEGRADO DEL SISTEMA DE ARCHIVOS DISTRIBUIDO (AWS EFS)
# ==============================================================================
# Creación física del punto de montaje local de la aplicación
mkdir -p /opt/tomcat/webapps/ROOT/uploads

# Registro no volátil del montaje NFSv4.1 persistente con soporte _netdev
echo "${efs_id}.efs.${region}.amazonaws.com:/ /opt/tomcat/webapps/ROOT/uploads efs defaults,_netdev,noatime,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2 0 0" >> /etc/fstab

# Inicialización segura del montaje local mediante fstab
mount -a -t efs || mount /opt/tomcat/webapps/ROOT/uploads

# CORRECCIÓN DE SEGURIDAD CRÍTICA: Cambiar propietario del directorio DESPUÉS de montar EFS
chown -R tomcat:tomcat /opt/tomcat/webapps/ROOT/uploads
chmod 750 /opt/tomcat/webapps/ROOT/uploads

# ==============================================================================
# 4. CONFIGURACIÓN DE RED Y REDIRECCIÓN DE PUERTOS
# ==============================================================================
# Modificación de server.xml para escuchar directamente en el puerto privilegiado 80
sed -i 's/port="8080"/port="80"/g' /opt/tomcat/conf/server.xml

# ==============================================================================
# 5. INTEGRACIÓN DE SECRETOS Y CONFIGURACIÓN XML DE TOMCAT
# ==============================================================================
# Obtención segura de las variables desde AWS Secrets Manager
SECRET_VAL=$(aws secretsmanager get-secret-value --secret-id "${secret_arn}" --region "${region}" --query SecretString --output text)
DB_USER=$(echo "$SECRET_VAL" | jq -r .db_user)
DB_PASS=$(echo "$SECRET_VAL" | jq -r .db_pass)
TOMCAT_USER=$(echo "$SECRET_VAL" | jq -r .tomcat_user)
TOMCAT_PASS=$(echo "$SECRET_VAL" | jq -r .tomcat_pass)
HMAC_SHA_KEY=$(echo "$SECRET_VAL" | jq -r .hmac_sha_key)

# Generación del archivo tomcat-users.xml alineado con el esquema formal de Tomcat 11
cat <<EOF > /opt/tomcat/conf/tomcat-users.xml
<?xml version="1.0" encoding="UTF-8"?>
<tomcat-users xmlns="http://tomcat.apache.org/xml" version="1.0">
    <role rolename="admin"/>
    <role rolename="admin-gui"/>
    <role rolename="manager"/>
    <role rolename="manager-gui"/>
    <user username="$TOMCAT_USER" password="$TOMCAT_PASS" roles="admin,admin-gui,manager,manager-gui"/>
</tomcat-users>
EOF
chown tomcat:tomcat /opt/tomcat/conf/tomcat-users.xml
chmod 644 /opt/tomcat/conf/tomcat-users.xml

# Configuramos el acceso remoto a Tomcat Manager y Host Manager para permitir conexiones desde cualquier IP.
# Sobrescribimos context.xml por completo eliminando la válvula de restricción para evitar errores de parseo multilínea en Tomcat 11.
cat << 'EOF' > /tmp/clean-context.xml
<?xml version="1.0" encoding="UTF-8"?>
<Context antiResourceLocking="false" privileged="true" >
    <CookieProcessor className="org.apache.tomcat.util.http.Rfc6265CookieProcessor" sameSiteCookies="strict" />
    <Manager sessionAttributeValueClassNameFilter="java\.lang\.(?:Boolean|Integer|Long|Number|String)|org\.apache\.catalina\.filters\.CsrfPreventionFilter\$LruCache(?:\$1)?|java\.util\.(?:Linked)?HashMap"/>
</Context>
EOF
cp /tmp/clean-context.xml /opt/tomcat/webapps/manager/META-INF/context.xml
cp /tmp/clean-context.xml /opt/tomcat/webapps/host-manager/META-INF/context.xml
chown tomcat:tomcat /opt/tomcat/webapps/manager/META-INF/context.xml
chown tomcat:tomcat /opt/tomcat/webapps/host-manager/META-INF/context.xml

# ==============================================================================
# 6. DEFINICIÓN DE LA UNIDAD DE SERVICIO SYSTEMD (TIPO SIMPLE)
# ==============================================================================
# Creamos un servicio systemd para Tomcat, configurando las variables de entorno necesarias 
# y asegurando que se inicie automáticamente al arrancar la instancia.
cat <<EOF > /etc/systemd/system/tomcat.service
[Unit]
Description=Apache Tomcat 11 Web Application Container
After=network-online.target
Wants=network-online.target
[Service]
Type=forking
AmbientCapabilities=CAP_NET_BIND_SERVICE
User=tomcat
Group=tomcat
RestartSec=10
Restart=always
Environment="JAVA_HOME=/usr/local/corretto-25"
Environment="PATH=/usr/local/corretto-25/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin"
Environment="CATALINA_HOME=/opt/tomcat"
Environment="CATALINA_BASE=/opt/tomcat"
Environment="CATALINA_PID=/opt/tomcat/temp/tomcat.pid"
Environment="JAVA_OPTS=-Djava.awt.headless=true -Djava.security.egd=file:/dev/./urandom"
Environment="CATALINA_OPTS=-Xms512M -Xmx1024M -server -XX:+UseParallelGC"
Environment="HMAC_SHA_KEY=$HMAC_SHA_KEY"
Environment="DB_HOST=localhost"
Environment="MYSQL_REMOTE_USER=$DB_USER"
Environment="MYSQL_REMOTE_PASS=$DB_PASS"
ExecStart=/opt/tomcat/bin/startup.sh
ExecStop=/opt/tomcat/bin/shutdown.sh
[Install]
WantedBy=multi-user.target
EOF

# Configuración de permisos y habilitación del servicio para 
# iniciar automáticamente al arrancar el sistema
chmod 644 /etc/systemd/system/tomcat.service
systemctl daemon-reload
systemctl enable tomcat
systemctl start tomcat

echo "Aprovisionamiento y optimización de Apache Tomcat 11 y Java 25 completados con éxito."
# Indice

[TOC]

## Resumen de las modificaciones propuestas en la arquitectura

!!! Note Nota
    En la instancia de **Cloud9** creada en el laboratorio se ha clonado un repositorio público propio en **`/cursoiac`** es una copia del repositorio del curso en donde en la carpeta **`/cursoiac/MIS_APUNTES`** se han ido tomando notas de las diferentes sesiones. En **`/cursoiac/MIS_APUNTES/sesion5`** se encuentra el código de Terraform modificado para esta propuesta, así como el script de User Data actualizado para instalar Tomcat 11 y Java Corretto 25 en lugar de Wordpress que se han adjuntado junto a esta entrega.

    **El repositorio tiene seteadas unas credenciales de GitHUb hasta Agosto por lo que cualquier commit y push se subirán correctamente al repositorio público de GitHub y se podrán revisar los cambios realizados en el código**.

**Nombre de la pila**: EC2-con-Tomcat11-y-MySQL8
* **AllowedIP**: 88.17.35.54/32
* **HmacShaKey**: CursoCefireIaCJunio2026!
* **InstanceType**: t3.medium
* **KeyName**: vockey
* **MysqlRemoteUser**: uremoto
* **MysqlRemotePass**: CursoCefireIaCJunio2026!
* **MysqlRootPass**: CursoCefireIaCJunio2026!!
* **TomcatPass**: CursoCefireIaCJunio2026!
* **TomcatUser**: tomcat

```shell
# Comando para cambiar a usuario root
sudo su

# Comando para revisar los puertos abiertos
ss -tlnp

# Comando para revisar los logs de cfn-init
tail -f /var/log/cfn-init-cmd.log

# Comando para revisar el estado del servicio de Tomcat
systemctl status tomcat

# Comando para revisar los logs de Tomcat
tail -n 50 /opt/tomcat/logs/catalina.out

# Comando para revisar el archivo de configuración de usuarios de Tomcat
cat /opt/tomcat/conf/tomcat-users.xml

# Comando para revisar los logs de MySQL
tail -f /var/log/mysqld.log

# Comando para conectarse a MySQL con el usuario root 
# y verificar si se ha creado el usuario remoto
mysql -u uremoto -pCursoCefireIaCJunio2026!
musql> quit

# Mostrar los logs de despliegue de Tomcat
tail -f /var/log/tomcat-deployments.log

aws configure
aws s3 cp app.war s3://NOMBRE_DE_TU_BUCKET/app.war
```

dam-deploy-bucket-017968781869-us-east-1
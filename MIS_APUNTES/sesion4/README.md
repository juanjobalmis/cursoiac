Debes crear un archivo terraform.tfvars con el siguiente contenido:

```hcl
# terraform.tfvars
# Credenciales para RDS y Tomcat que se enviarán a Secrets Manager

db_user     = "admin"
db_pass     = "<tu clave segura para el usuario admin de la base de datos>"
tomcat_user = "tomcatadmin"
tomcat_pass = "<tu clave segura para el usuario admin de Tomcat>"
domain_name = "<Tu dominio para el certificado ACM, por ejemplo: aws.tudominio.com>"
admin_ip    = "<La ip púlica desde la que se permitirá el acceso directo al RDS, en formato CIDR>"
hmac_sha_key = "<Tu clave para firma de tokens de 32 caracteres>"
```

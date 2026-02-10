# Documentación Técnica
Este es una solución para la empresa TechSolutions que desarrolla aplicaciones backend en SpringBoot, las cuales deben desplegarse de forma automatizada y controlada.

## 1. Instalación y configuración de Jenkins
- Crear el contenedor jenkins-container
```
docker container run -d -p 8080:8080 -p 50000:50000 -v jenkins_home:/var/jenkins_home --name jenkins-container jenkins/jenkins:lts
```
- Para desbloquear Jenkins usar estos comandos o fijarse en los logs del container en docker desktop
```
winpty docker exec -it id_container bash
cat /var/jenkins_home/secrets/initialAdminPassword
```
Instalar maven en el contenedor de jenkins
```
# Acceder al shell
winpty docker exec -u root -it jenkins-container bash

# Instalar maven
apt-get update
apt-get install -y maven
```
Crear el ssh en el contenedor de jenkins
```
# Crear las llaves en cliente 
ssh-keygen

# Copiar las llaves con las credenciales del usuario del host de destino
ssh-copy-id osboxes@192.168.100.161

# Entrar a la VM desde el contenedor mediante ssh
ssh osboxes@192.168.100.161
```

## 2. Instalación y configuración de la máquina virtual en VirtualBox
1. Descargar la app Oracle VirtualBox Manager
```
https://www.virtualbox.org/
```
2. Descargar la imagen ISO de UbuntuServer
```
https://www.osboxes.org/ubuntu-server/
```
3. Crear la VM 
```
a) Darle a New
b) Specify virtual disk
    i) Seleccionar la ISO qué descargamos en este caso UBUNTU SERVER
c) Nombrar la VM
d) FInish
```
4. En la VM añadir en Network Port Forwarding SSH port 2222
5. Las credenciales por defecto para osboxes son:
```
user: osboxes
password: osboxes.org
```
6. Verificar qué tenga instalado el SSH
```
sudo systemctl status ssh
```
7. Iniciar el servicio ssh
```
sudo systemctl start ssh
```
8. Cambiar la VM a Bridge Adapter y cambiar el Mac Addres en settings -> network
9. Instalar vim en la VM
```
sudo apt install vim
```
10. Dentro de la consola de la VM
```
# Primero 
sudo cp /etc/netplan/50-cloud-init.yaml /etc/netplan/01-netcfg.yaml

sudo vi /etc/netplan/01-netcfg.yaml

# Luego editar con esto

network:
    version: 2
    renderer: networkd
    ethernets:
        enp0s3:
            dhcp4: true
            addresses:
                - 192.168.100.161/24
            routes:
                - to: default
                  via: 192.168.100.1
            nameservers:
                addresses:
                    - 8.8.8.8
                    - 1.1.1.1

# Por último 

sudo netplan apply
```
11. Instalar iputils-ping
```
sudo apt update && sudo apt install -y iputils-ping
```
12. Crear llaves ssh id_rsa para ingresar desde nuestra computadora local a la VM
```
# Abrir git bash como administrador en nuestra máquina local
ssh-keygen -f id_rsa_161

# Copiar el key generado a la VM
ssh-copy-id -i id_rsa_161 osboxes@192.168.100.161

# Finalmente entrar con el ssh key
ssh osboxes@192.168.100.161 -i id_rsa_161
```
13. Instalar java
```
sudo apt update
sudo apt install openjdk-17-jdk -y
java -version
```
14. Crear una carpeta para el proyecto
```
pwd 
mkdir artifacts
mkdir artifacts/spring-boot-private
```
15. Crear el directorio para el deploy
```
sudo mkdir /opt/spring-boot-app
cd /opt/
cd spring-boot-app
vi deploy.sh

# Habilitar antes que nada el sudo su y pegar el archivo deploy.sh
    sudo su
    :set paste ENTER
    i
    ctrl + shift + insert
    ESC
    :wq

#Le damos permisos de ejecución
sudo chmod +x deploy.sh

# Crear las carpetas logs y versions
mkdir logs versions

# Para que Jenkins pueda trabajar sin restricciones
sudo chown -R osboxes:osboxes /opt/spring-boot-app

```
16. Configuración para qué el deploy sea exitoso
```
# En la terminal de la VM Repository
sudo visudo

# Agregar esta regla al final del todo
osboxes ALL=(ALL) NOPASSWD: /opt/spring-boot-app/deploy.sh
```

## 3. Creación del proyecto java en local
Una vez creado el proyecto en local
```
# Abrir la consola y verificar qué corre

mvn clean package
mvn spring-boot:run -Dspring-boot.run.arguments=--server.port=8081
```

## 4. Configuración del job en Jenkins - springboot-app-private-deploy


- Configurar un Github personal access token
```
# Entrar a Settings/DeveloperSettings -> Fine-grained-tokens
https://github.com/settings/personal-access-tokens

# Darle a generate new token, darle un nombre al token y todos los permisos necesarios para el repositorio
```
- Crear una credential en jenkins
```
# Dirigirse aquí y luego Add credentials
http://localhost:8080/manage/credentials/store/system/domain/_/

# Colocar username with password
username: nombre de usuario de github 
password: token qué generamos en github
ID: github-token

Y darle a Create
```
- En la configuración del job
```
# Seleccionar GitHub project
https://github.com/JuanAndresRomanYanez/springboot-app-private/

# En Triggers
GitHub hook trigger for GITScm polling

# En Pipeline -> Pipeline script

Pegar el archivo Jenkinsfile

```

- Crear una URL pública mediante un túnel usando Ngrok
```
cd C:\Users\darkandy\Downloads\NGROK
ngrok http 8080
```

- Configurar un webhook en el repositorio de github
```
# Ubicados en el proyecto darle a settings -> Webhooks, Add webhook
1. En Payload URL colocar el URL qué nos da ngrok al payload URL + /github-webhook/ Por ejemplo:
https://abcdefghijkasdf.ngrok-free.app/github-webhook/
2. Content-type: application/json
3. Enable SSL verification
4. Just the push event
5. Active
```


## 4. Configuración de Nginx
Ingresar a la VM
```
# Instalar

sudo apt update
sudo apt install nginx -y

# Verificar

nginx -v

# Iniciar y Habilitar Nginx

sudo systemctl start nginx
sudo systemctl enable nginx
sudo systemctl status nginx
```
Configurar Reverse Proxy/Load Balancer
```
sudo vim /etc/nginx/conf.d/springboot-lb.conf
```
Agregar una configuración
```
upstream springboot_backend {
    least_conn;

    server 127.0.0.1:8081 weight=8 max_fails=3 fail_timeout=10s;
    server 127.0.0.1:8082 weight=2 max_fails=3 fail_timeout=10s;
}

server {
    listen 80;
    server_name 192.168.100.161;

    location / {
        proxy_pass http://springboot_backend;

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        proxy_connect_timeout 5s;
        proxy_read_timeout 30s;
    }
}
```
Probar y recargar Nginx
```
sudo nginx -t
sudo systemctl reload nginx
sudo systemctl status nginx
```
Para verificar que funciona
```
# desde la VM en artifacts/spring-boot-private

nohup java -jar demo-0.0.1-SNAPSHOT.jar --server.port=8081 > app.log 2>&1 &
nohup java -jar demo-0.0.1-SNAPSHOT.jar --server.port=8082 > app.log 2>&1 &

# Para eliminar esos procesos

top | grep java
sudo kill number_of_process
```


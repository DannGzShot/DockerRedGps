<!--
Autor: DannGzShot
Fecha de creacion: 16/03/2026
Descripcion: Documenta instalacion, uso y mantenimiento del entorno Docker local/global REDGPS.
-->

# REDGPS - Entorno Docker local

Esta documentacion explica como instalar y levantar el entorno Docker local de REDGPS en Linux y macOS.

El repositorio Docker contiene solamente la integracion de contenedores: `Dockerfile`, `docker-compose.yml`, `Makefile`, configuracion Apache/PHP, scripts auxiliares y plantillas seguras. No incluye los repositorios de aplicacion `dev`, `qa` ni `master`.

Repositorio:

```bash
https://github.com/DannGzShot/DockerRedGps.git
```

Si tu cuenta tiene una llave SSH configurada en GitHub, tambien puedes usar:

```bash
git@github.com:DannGzShot/DockerRedGps.git
```

## 1. Alcance

El entorno levanta localmente:

| Servicio | Contenedor | Uso |
|---|---|---|
| `web` | `redgps_web` | Gateway HTTPS local |
| `dev_web` | `redgps_dev_web` | Backend DEV |
| `qa_web` | `redgps_qa_web` | Backend QA |

MASTER no se levanta como servicio activo en este `docker-compose.yml`.

La estructura esperada es una carpeta global donde conviven este repo Docker y los repositorios de aplicacion:

```text
work/
├── dataservice/
├── dev/
│   ├── atomic/
│   ├── commons/
│   ├── partners/
│   ├── redgps/
│   └── reportes/
├── docker/
├── docs/
├── docker-compose.yml
├── Dockerfile
├── Makefile
├── qa/
│   ├── atomic/
│   ├── commons/
│   ├── partners/
│   ├── redgps/
│   └── reportes/
└── .env
```

## 2. Instalar Docker antes de clonar

Si la computadora no tiene Docker, instalalo primero.

### Linux Ubuntu/Debian

Comandos basados en la instalacion oficial de Docker Engine para Ubuntu:

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl

sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

sudo tee /etc/apt/sources.list.d/docker.sources >/dev/null <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

sudo systemctl enable --now docker
sudo usermod -aG docker "$USER"
```

Para que el grupo `docker` aplique, normalmente basta con cerrar esa terminal y abrir una terminal nueva. No es necesario apagar la computadora. Si en la terminal nueva Docker sigue pidiendo `sudo`, entonces reinicia la sesion de usuario del sistema o reinicia la computadora. Luego valida:

```bash
docker version
docker compose version
docker run --rm hello-world
```

Para otras distribuciones Linux, usa la guia oficial de Docker Engine para tu distribucion.

### macOS con Homebrew

```bash
brew install --cask docker
open -a Docker
```

Despues de abrir la aplicacion de Docker y esperar a que termine de iniciar, valida:

```bash
docker version
docker compose version
```

## 3. Clonar o instalar el repositorio Docker

### Opcion A: carpeta `work/` nueva o vacia

Usa HTTPS por defecto. Esta opcion no requiere llave SSH de GitHub si el repositorio es publico:

```bash
mkdir -p ~/Documentos/work
cd ~/Documentos
git clone https://github.com/DannGzShot/DockerRedGps.git work
cd work
```

Si prefieres SSH y ya tienes tu llave registrada en GitHub:

```bash
mkdir -p ~/Documentos/work
cd ~/Documentos
git clone git@github.com:DannGzShot/DockerRedGps.git work
cd work
```

### Opcion B: ya existe `work/` con `dev`, `qa`, `master` u otros archivos

No ejecutes `git clone ... work` si `work/` ya existe y tiene archivos, porque Git puede devolver error al no estar vacia. La opcion mas segura es clonar en una carpeta temporal y copiar el contenido al directorio `work/`.

Con HTTPS:

```bash
mkdir -p ~/tmp
cd ~/tmp
rm -rf DockerRedGps
git clone https://github.com/DannGzShot/DockerRedGps.git DockerRedGps

rsync -av --exclude='.git' DockerRedGps/ ~/Documentos/work/
cd ~/Documentos/work
```

Con SSH:

```bash
mkdir -p ~/tmp
cd ~/tmp
rm -rf DockerRedGps
git clone git@github.com:DannGzShot/DockerRedGps.git DockerRedGps

rsync -av --exclude='.git' DockerRedGps/ ~/Documentos/work/
cd ~/Documentos/work
```

Si quieres crear la carpeta temporal y clonar dentro usando punto al final:

```bash
mkdir -p ~/tmp/DockerRedGps
cd ~/tmp/DockerRedGps
git clone https://github.com/DannGzShot/DockerRedGps.git .
rsync -av --exclude='.git' ./ ~/Documentos/work/
cd ~/Documentos/work
```

El comando `rsync` copia solamente los archivos del repo Docker y conserva tus carpetas existentes. Si algun archivo Docker ya existe en `work/`, sera actualizado.

### Nota sobre el error `Permission denied (publickey)`

Si intentas clonar por SSH y aparece:

```text
git@github.com: Permission denied (publickey).
fatal: No se pudo leer del repositorio remoto.
```

significa que esa computadora no tiene una llave SSH registrada en GitHub, o GitHub no reconoce esa llave para tu usuario. Para este repositorio de pruebas, usa HTTPS:

```bash
git clone https://github.com/DannGzShot/DockerRedGps.git
```

Usa SSH solo si ya configuraste tu llave publica en GitHub y validaste:

```bash
ssh -T git@github.com
```

## 4. Preparar repositorios de aplicacion

Este repo no incluye `dev`, `qa`, `master` ni el codigo de las aplicaciones. Deben existir al mismo nivel que `docker-compose.yml`.

Vista esperada despues de instalar DockerRedGps sobre tu carpeta global:

```text
work/
├── docker-compose.yml
├── Dockerfile
├── Makefile
├── .env.example
├── docker/
├── docs/
├── dataservice/
├── dev/
├── qa/
└── master/
```

Dentro de `dev/` y `qa/` se esperan los repos o carpetas usados por los volumenes de Docker:

```text
dev/
├── atomic/
├── commons/
├── partners/
├── redgps/
└── reportes/

qa/
├── atomic/
├── commons/
├── partners/
├── redgps/
└── reportes/
```

Ejemplo:

```bash
cd ~/Documentos/work

# Ejemplos. Reemplaza las URL por los repos reales de la organizacion.
git clone <REPO_DEV> dev
git clone <REPO_QA> qa
git clone <REPO_DATASERVICE> dataservice
```

La integracion Docker monta rutas como:

```text
./dev/redgps
./dev/partners
./dev/reportes
./dev/atomic
./dev/commons
./qa/redgps
./qa/partners
./qa/reportes
./qa/atomic
./qa/commons
./dataservice
```

Si una ruta no existe, Docker puede crear una carpeta vacia y la aplicacion no funcionara correctamente. Verifica la estructura antes de levantar.

## 5. Crear archivo `.env`

El archivo `.env` no se sube al repositorio. Crea uno desde la plantilla:

```bash
cp .env.example .env
```

Si tu explorador de archivos no muestra `.env.example` por ser un archivo oculto, tambien hay una copia visible:

```bash
cp examples/env.example .env
```

Edita `.env` con valores de tu computadora y tus permisos:

```env
SSH_TUNNEL_USER=your-ssh-user
SSH_TUNNEL_HOST=your-ssh-host
SSH_TUNNEL_PORT=6611
SSH_TUNNEL_LOCAL_PORT=3306
SSH_TUNNEL_REMOTE_DB_HOST=127.0.0.1
SSH_TUNNEL_REMOTE_DB_PORT=3306
SSH_TUNNEL_EXCLUDE_HOST=your-ssh-host
SSHUTTLE_REMOTE=qa

REDIS_REMOTE_PATH=/home/redgps/redisCache.ini
REDIS_LOCAL_PATH=docker/php/redisCache.ini
```

No subas `.env`, llaves privadas, certificados privados ni contrasenas reales.

## 6. Configurar SSH

El entorno usa `scp` y `sshuttle` contra el alias SSH que definas. Configura `~/.ssh/config` con valores reales de tu acceso:

```sshconfig
Host *
    ServerAliveInterval 10
    HostKeyAlgorithms +ssh-rsa
    PubkeyAcceptedKeyTypes +ssh-rsa

Host qa
    HostName <qa-public-host-or-ip>
    User <ssh-user>
    Port 6611
    IdentityFile ~/.ssh/id_rsa
    IdentitiesOnly yes
```

Valida:

```bash
ssh -F "$HOME/.ssh/config" qa
```

Si no tienes acceso SSH autorizado, `make redis-config-qa` y `make vpn-qa` no podran funcionar.

## 7. Instalar herramientas auxiliares

El `Makefile` puede instalar herramientas auxiliares para Linux y macOS:

```bash
make install-tools
```

Instala o valida principalmente:

- `sshuttle`
- `openssl`
- `curl`
- certificados CA del sistema cuando aplica

Tambien puedes validar el entorno local:

```bash
make doctor
```

## 8. Configurar `/etc/hosts`

Dominios locales activos:

```text
dev.redgps.local
dev.reportes.local
dev.partners.local
qa.redgps.local
qa.reportes.local
qa.partners.local
```

Solo se usa formato con punto. No uses dominios con guion bajo.

Instalacion automatica:

```bash
make hosts-install
```

Ver lo que se agregara:

```bash
make hosts-print
```

Configuracion manual equivalente:

```bash
sudo sh -c 'cat >> /etc/hosts' <<'EOF'

# REDGPS Docker local
127.0.0.1 dev.redgps.local
127.0.0.1 dev.reportes.local
127.0.0.1 dev.partners.local
127.0.0.1 qa.redgps.local
127.0.0.1 qa.reportes.local
127.0.0.1 qa.partners.local
EOF
```

## 9. Certificados HTTPS locales

Genera certificados locales:

```bash
make certs
```

Instala la CA local en el sistema:

```bash
make certs-install
```

En Linux usa `/usr/local/share/ca-certificates` y `update-ca-certificates`.

En macOS usa `security add-trusted-cert` contra el System Keychain.

Los archivos generados en `docker/apache/certs/` no se suben al repositorio. La carpeta se conserva con `.gitkeep`.

## 10. Configuracion Redis remota

El archivo real `docker/php/redisCache.ini` no se versiona porque contiene credenciales.

Para traerlo desde el servidor autorizado:

```bash
make redis-config-qa
```

El comando usa:

```text
$(SSHUTTLE_REMOTE):$(REDIS_REMOTE_PATH) -> $(REDIS_LOCAL_PATH)
```

Por defecto:

```text
qa:/home/redgps/redisCache.ini -> docker/php/redisCache.ini
```

Si no tienes acceso remoto, crea una copia local desde la plantilla y completa los valores manualmente:

```bash
cp docker/php/redisCache.ini.example docker/php/redisCache.ini
```

Tambien existe una copia visible en:

```bash
cp examples/redisCache.ini.example docker/php/redisCache.ini
```

No subas `docker/php/redisCache.ini`.

Si tu entorno requiere `docker/var-cache/config/general.cfg`, crealo desde la plantilla:

```bash
cp docker/var-cache/config/general.cfg.example docker/var-cache/config/general.cfg
```

O usando la copia visible:

```bash
cp examples/general.cfg.example docker/var-cache/config/general.cfg
```

Edita `general.cfg` con valores autorizados. No subas `docker/var-cache/config/general.cfg`.

## 11. Setup rapido

Cuando ya tienes Docker instalado, repos de aplicacion clonados y acceso SSH configurado:

```bash
make setup-qa
```

Ese comando ejecuta:

```text
make install-tools
make hosts-install
make certs
make certs-install
make redis-config-qa
make build
```

Si no necesitas Redis remoto o no tienes acceso SSH, ejecuta los pasos manualmente y omite `make redis-config-qa`.

## 12. Levantar y apagar contenedores

```bash
make up
make ps
make down
```

Reconstruir imagen:

```bash
make build
```

Comandos Docker equivalentes:

```bash
docker compose up -d
docker compose up -d --build
docker compose ps
docker compose down
```

## 13. Abrir URLs locales

Usa HTTPS con puerto `8001`:

| Ambiente | Plataforma | URL |
|---|---|---|
| DEV | RedGPS | `https://dev.redgps.local:8001/` |
| DEV | Reportes | `https://dev.reportes.local:8001/` |
| DEV | Partners | `https://dev.partners.local:8001/` |
| QA | RedGPS | `https://qa.redgps.local:8001/` |
| QA | Reportes | `https://qa.reportes.local:8001/` |
| QA | Partners | `https://qa.partners.local:8001/` |

Puertos usados:

| Puerto | Uso |
|---:|---|
| `8001` | Gateway HTTPS local |
| `18080` | Gateway HTTP local; redirige a HTTPS |
| `18081` | Backend interno DEV |
| `18082` | Backend interno QA |

## 14. Tunel SSH con sshuttle

Cuando el flujo local necesita resolver servicios remotos:

```bash
make vpn-qa
```

El comando usa el alias `qa` de `~/.ssh/config` y excluye del tunel la IP publica definida en `SSH_TUNNEL_EXCLUDE_HOST`.

Ejemplo manual equivalente:

```bash
sudo sshuttle --dns --disable-ipv6 \
  -r qa \
  -e "ssh -F $HOME/.ssh/config" \
  -x <qa-public-ip>/32 \
  -x 127.0.0.0/8 \
  0/0
```

Mantén este proceso abierto mientras necesites acceso remoto.

## 15. Logs

Comandos por ambiente:

```bash
make logs-dev
make logs-qa
make logs-gateway
```

Variantes disponibles:

```bash
make logs-dev-apache
make logs-dev-php
make logs-dev-cli
make logs-qa-apache
make logs-qa-php
make logs-qa-cli
```

Actualmente esas variantes apuntan al contenedor web del ambiente correspondiente porque no hay servicios separados por Apache/PHP/CLI.

Limpiar logs:

```bash
make logs-clear
make logs-clear-dev
make logs-clear-qa
make logs-clear-gateway
```

## 16. Archivos que no se suben

El `.gitignore` protege secretos y datos generados, incluyendo:

- `.env`
- `docker/php/redisCache.ini`
- `docker/ssh/*`
- `docker/apache/certs/*`
- `docker/runtime/**`
- `docker/var-cache/**`
- `master/docker/var-cache/**`
- archivos `.key`, `.pem`, `.p12`, `.pfx`, `.csr`, `.srl`
- carpetas `secrets/`
- datos operativos generados por `dataservice`

Las carpetas necesarias se conservan con `.gitkeep`.

Plantillas seguras que si se suben:

```text
.env.example
docker/php/redisCache.ini.example
docker/var-cache/config/general.cfg.example
examples/env.example
examples/redisCache.ini.example
examples/general.cfg.example
```

## 17. Problemas comunes

### Docker no responde

Verifica:

```bash
docker version
docker compose version
docker compose ps
```

En Linux, si Docker requiere `sudo`, revisa que tu usuario pertenezca al grupo `docker` y vuelve a iniciar sesion.

### El navegador no abre el dominio local

Revisa:

```bash
make hosts-print
cat /etc/hosts | grep redgps.local
docker compose ps
```

### El navegador marca certificado no confiable

Ejecuta:

```bash
make certs
make certs-install
```

Cierra y vuelve a abrir el navegador si mantiene cache de certificados.

### Falla `make redis-config-qa`

Valida SSH:

```bash
ssh -F "$HOME/.ssh/config" qa
```

Si no tienes acceso, crea `docker/php/redisCache.ini` desde el `.example` y usa valores autorizados.

### El sitio carga lento

Puede pasar si depende del tunel SSH o de servicios remotos. Revisa que `make vpn-qa` siga activo y que la red remota responda.

## 18. Flujo recomendado

```bash
cd ~/Documentos/work
cp .env.example .env
make install-tools
make hosts-install
make certs
make certs-install
make redis-config-qa
make build
make up
make vpn-qa
```

Luego abre:

```text
https://dev.redgps.local:8001/
https://qa.redgps.local:8001/
```

## 19. Fuentes oficiales utiles

- Docker Engine para Linux: https://docs.docker.com/engine/install/
- Docker Engine en Ubuntu: https://docs.docker.com/engine/install/ubuntu/

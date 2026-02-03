# Plataforma de Despliegue con Docker y Proxy Inverso

Este proyecto implementa una infraestructura completa basada en Docker para alojar aplicaciones web de múltiples usuarios. Incluye proxy inverso con Nginx, certificados SSL automáticos con Let's Encrypt, monitorización con Prometheus/Grafana y gestión de contenedores con Portainer.

## 📋 Tabla de Contenidos

- [Requisitos de Red](#-requisitos-de-red)
- [Gestión de Usuarios](#-gestión-de-usuarios)
- [Despliegue de Aplicaciones](#-despliegue-de-aplicaciones)
- [Dominios y Certificados SSL](#-dominios-y-certificados-ssl)
- [Monitorización y Métricas](#-monitorización-y-métricas)
- [Mantenimiento Básico](#️-mantenimiento-básico)

---

## 🌐 Requisitos de Red

### Puertos necesarios

| Puerto | Servicio | Descripción |
|--------|----------|-------------|
| `80` | HTTP | Tráfico web sin cifrar (redirige a HTTPS) |
| `443` | HTTPS | Tráfico web cifrado con SSL |
| `22` | SSH | Administración remota y subida de archivos (SCP) |

### Redes Docker

- **`proxy`**: Red externa para comunicación entre el proxy inverso y las aplicaciones.
- **`monitor`**: Red interna para los servicios de monitorización.

> ⚠️ **Importante**: La red `proxy` debe crearse antes de iniciar los servicios:
> ```bash
> docker network create proxy
> ```

### Arquitectura

El sistema utiliza:
- **nip.io** para resolución DNS dinámica basada en IP en red local (ej: `app.192.168.1.100.nip.io`)
- **Cloudflare Tunnel** para exponer servicios a internet sin necesidad de IP pública ni abrir puertos en el router
- **Dominio propio** (ej: `tudominio.dpdns.org`) gestionado a través de Cloudflare

> 💡 **Cloudflare Tunnel** permite saltar restricciones como CGNAT, haciendo accesibles los servicios desde cualquier lugar.

---

## 👥 Gestión de Usuarios

### Crear un nuevo usuario

Ejecuta el script con privilegios de root:

```bash
sudo ./create-user.sh <nombre_usuario>
```

### ¿Qué hace el script?

1. **Crea el usuario** con shell `/bin/bash`
2. **Establece contraseña** por defecto: `pass1234`
3. **Añade al grupo `docker`** para gestionar contenedores sin sudo
4. **Crea el directorio de trabajo**: `/home/<usuario>/apps`
5. **Asigna un rango de puertos exclusivo** (10 puertos por usuario, empezando en 8000)
6. **Genera archivo de información** con las instrucciones para el usuario

### Sistema de puertos

Cada usuario recibe un rango de 10 puertos TCP reservados:

| Usuario | Rango de Puertos |
|---------|------------------|
| Usuario 1 | 8000 - 8009 |
| Usuario 2 | 8010 - 8019 |
| Usuario 3 | 8020 - 8029 |
| ... | ... |

El archivo `/opt/plataforma/ultimo_puerto.txt` mantiene el registro del último puerto asignado.

### Conexión del usuario al servidor

Una vez creado el usuario, puede conectarse por SSH:

```bash
ssh nombre_usuario@IP_SERVIDOR
```

- **Contraseña por defecto**: `pass1234`
- **Directorio de trabajo**: `/home/nombre_usuario/apps`

> 💡 **Consejo**: Se recomienda que el usuario cambie la contraseña tras el primer acceso con el comando `passwd`.

---

## 🚀 Despliegue de Aplicaciones

### Pasos mínimos para desplegar

**1. Subir archivos al servidor**
```bash
scp -r ./mi-proyecto usuario@IP_SERVIDOR:~/apps/
```

**2. Crear el `docker-compose.yml`**

Puedes usar **nip.io** (solo red local) o tu **subdominio de Cloudflare** (acceso desde internet):

```yaml
version: "3.8"
services:
  mi-app:
    image: nginx:latest  # o tu imagen personalizada
    container_name: mi-app
    restart: unless-stopped
    environment:
      # Opción 1: Solo red local (nip.io)
      # - VIRTUAL_HOST=mi-app.192.168.1.100.nip.io
      # Opción 2: Acceso desde internet (Cloudflare) - RECOMENDADO
      - VIRTUAL_HOST=mi-app.tudominio.dpdns.org
      - VIRTUAL_PORT=80
    networks:
      - proxy

networks:
  proxy:
    external: true
```

> ⚠️ **Importante**: Para que funcione con Cloudflare, el subdominio debe estar configurado en el túnel del administrador o usar un wildcard DNS (`*.tudominio.dpdns.org`).

**3. Conectar por SSH y lanzar**
```bash
ssh usuario@IP_SERVIDOR
cd ~/apps/mi-proyecto
docker compose up -d
```

**4. Acceder a la aplicación**
- URL: `http://mi-app.TU_IP.nip.io`

### Variables de entorno importantes

| Variable | Descripción |
|----------|-------------|
| `VIRTUAL_HOST` | Dominio para acceder a la app |
| `VIRTUAL_PORT` | Puerto interno del contenedor (por defecto 80) |
| `LETSENCRYPT_HOST` | Dominio para el certificado SSL (debe coincidir con VIRTUAL_HOST) |
| `LETSENCRYPT_EMAIL` | Email para notificaciones de Let's Encrypt |

---

## 🔒 Dominios y Certificados SSL

### Opción 1: nip.io (solo red local)

nip.io resuelve automáticamente cualquier subdominio con una IP:
- `app.192.168.1.100.nip.io` → resuelve a `192.168.1.100`

> ⚠️ Solo funciona dentro de la red local. No accesible desde internet.

### Opción 2: Cloudflare Tunnel + Dominio propio (RECOMENDADO)

Esta es la opción recomendada ya que:
- ✅ Funciona sin IP pública
- ✅ Salta CGNAT y restricciones de red
- ✅ SSL gestionado automáticamente por Cloudflare
- ✅ Accesible desde cualquier lugar

**Configuración del administrador:**

1. Crear un túnel en [Cloudflare Zero Trust](https://one.dash.cloudflare.com/)
2. Obtener el `TUNNEL_TOKEN` y añadirlo al `docker-compose.yml` principal
3. Configurar un **wildcard DNS** (`*.tudominio.dpdns.org`) apuntando al túnel
4. En la configuración del túnel, añadir una regla que redirija `*.tudominio.dpdns.org` → `http://nginx-proxy:80`

**Configuración del usuario:**

Simplemente usa tu subdominio en el `docker-compose.yml`:

```yaml
environment:
  - VIRTUAL_HOST=mi-app.tudominio.dpdns.org
  - VIRTUAL_PORT=80
```

> 📝 **Nota**: Con Cloudflare Tunnel, el SSL lo gestiona Cloudflare automáticamente. No necesitas configurar Let's Encrypt.

### Opción 3: Let's Encrypt (requiere IP pública)

Si tienes IP pública y puertos 80/443 abiertos:

```yaml
environment:
  - VIRTUAL_HOST=mi-app.midominio.com
  - VIRTUAL_PORT=80
  - LETSENCRYPT_HOST=mi-app.midominio.com
  - LETSENCRYPT_EMAIL=tu-email@dominio.com
```

El contenedor `nginx-proxy-letsencrypt` generará automáticamente el certificado.

---

## 📊 Monitorización y Métricas

### Servicios de monitorización disponibles

| Servicio | URL | Descripción |
|----------|-----|-------------|
| **Grafana** | `grafana.TU_IP.nip.io` | Dashboards y visualización de métricas |
| **Prometheus** | `prometheus.TU_IP.nip.io` | Base de datos de métricas y consultas |
| **Portainer** | `portainer.TU_IP.nip.io` | Gestión visual de contenedores Docker |

### Métricas recopiladas

**Node Exporter** recoge métricas del sistema host:
- Uso de CPU
- Memoria RAM disponible/usada
- Espacio en disco
- Tráfico de red
- Carga del sistema

### Configurar Grafana

1. Accede a `http://grafana.TU_IP.nip.io`
2. Credenciales por defecto: `admin` / `admin`
3. Añade Prometheus como Data Source:
   - URL: `http://prometheus:9090`
4. Importa dashboards:
   - **Node Exporter Full**: ID `1860`
   - **Docker Dashboard**: ID `893`

### Verificar que las métricas funcionan

```bash
# Ver métricas de Node Exporter
curl http://localhost:9100/metrics

# Consultar Prometheus
curl "http://localhost:9090/api/v1/query?query=up"
```

---

## 🛠️ Mantenimiento Básico

### Arrancar servicios

> ⚠️ **Importante**: El archivo `docker-compose.yml` usa la variable `${SERVER_IP}` para generar los dominios nip.io. Debes definirla cada vez que arranques los servicios.

```bash
# Arrancar toda la infraestructura (con IP automática)
SERVER_IP=$(hostname -I | awk '{print $1}') docker compose up -d

# Arrancar un servicio específico
SERVER_IP=$(hostname -I | awk '{print $1}') docker compose up -d grafana
```

### Parar servicios

```bash
# Parar todos los servicios (sin eliminar contenedores)
docker compose stop

# Parar y eliminar contenedores
docker compose down

# Parar un servicio específico
docker compose stop prometheus
```

### Actualizar servicios

```bash
# Descargar las últimas versiones de las imágenes
docker compose pull

# Recrear los contenedores con las nuevas imágenes
docker compose up -d --force-recreate

# Actualizar un servicio específico
docker compose pull grafana
docker compose up -d --force-recreate grafana
```

### Ver logs

```bash
# Logs de todos los servicios
docker compose logs

# Logs en tiempo real
docker compose logs -f

# Logs de un servicio específico
docker compose logs nginx-proxy
docker compose logs -f grafana
```

### Comandos útiles de diagnóstico

```bash
# Ver estado de los contenedores
docker compose ps

# Ver consumo de recursos en tiempo real
docker stats

# Ver redes Docker
docker network ls

# Inspeccionar la red proxy
docker network inspect proxy

# Reiniciar un servicio con problemas
docker compose restart nginx-proxy
```

### Limpieza del sistema

```bash
# Eliminar contenedores parados
docker container prune

# Eliminar imágenes sin usar
docker image prune

# Eliminar volúmenes sin usar (¡CUIDADO! Borra datos)
docker volume prune

# Limpieza completa
docker system prune -a
```

---

## 📁 Estructura del Proyecto

```
Proyecto/
├── docker-compose.yml      # Infraestructura principal
├── create-user.sh          # Script para crear usuarios
├── prometheus/
│   └── prometheus.yml      # Configuración de Prometheus
├── app_prueba/
│   └── docker-compose.yml  # Ejemplo de aplicación
├── certs/                  # Certificados SSL (generados automáticamente)
├── vhost/                  # Configuraciones virtuales de Nginx
└── html/                   # Archivos estáticos para validación SSL
```

---

## ❓ Solución de Problemas

### La aplicación no es accesible

1. Verifica que el contenedor está corriendo:
   ```bash
   docker ps | grep mi-app
   ```
2. Comprueba los logs del proxy:
   ```bash
   docker logs nginx-proxy
   ```
3. Verifica que está conectado a la red `proxy`:
   ```bash
   docker network inspect proxy
   ```

### El certificado SSL no se genera

1. Comprueba que el puerto 80 es accesible desde internet
2. Revisa los logs:
   ```bash
   docker logs nginx-proxy-letsencrypt
   ```
3. Verifica que `LETSENCRYPT_HOST` coincide con `VIRTUAL_HOST`

### Prometheus no recoge métricas

1. Verifica que Node Exporter está corriendo:
   ```bash
   docker logs node-exporter
   ```
2. Comprueba la configuración en `prometheus/prometheus.yml`
3. Accede a Prometheus y verifica los targets: `http://prometheus.TU_IP.nip.io/targets`

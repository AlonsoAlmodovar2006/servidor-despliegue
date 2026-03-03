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
- **Dominio propio** (`alonso.servidorgp.somosdelprieto.com`) con subdominios para cada servicio
- **nginx-proxy** como proxy inverso que enruta el tráfico según el subdominio
- **Let's Encrypt** para certificados SSL automáticos

Los servicios se acceden mediante subdominios con el formato `servicio.alonso.servidorgp.somosdelprieto.com`. Es necesario tener un registro DNS wildcard (`*.alonso.servidorgp.somosdelprieto.com`) apuntando a la IP del servidor.

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

Usa un subdominio de `alonso.servidorgp.somosdelprieto.com`:

```yaml
services:
  mi-app:
    image: nginx:latest  # o tu imagen personalizada
    container_name: mi-app
    restart: unless-stopped
    environment:
      - VIRTUAL_HOST=mi-app.alonso.servidorgp.somosdelprieto.com
      - VIRTUAL_PORT=80
      - LETSENCRYPT_HOST=mi-app.alonso.servidorgp.somosdelprieto.com
    networks:
      - proxy

networks:
  proxy:
    external: true
```

> ⚠️ **Importante**: Es necesario que exista un registro DNS wildcard (`*.alonso.servidorgp.somosdelprieto.com`) apuntando a la IP del servidor para que los subdominios resuelvan correctamente.

**3. Conectar por SSH y lanzar**
```bash
ssh usuario@IP_SERVIDOR
cd ~/apps/mi-proyecto
docker compose up -d
```

**4. Acceder a la aplicación**
- URL: `https://mi-app.alonso.servidorgp.somosdelprieto.com`

### Variables de entorno importantes

| Variable | Descripción |
|----------|-------------|
| `VIRTUAL_HOST` | Dominio para acceder a la app |
| `VIRTUAL_PORT` | Puerto interno del contenedor (por defecto 80) |
| `LETSENCRYPT_HOST` | Dominio para el certificado SSL (debe coincidir con VIRTUAL_HOST) |
| `LETSENCRYPT_EMAIL` | Email para notificaciones de Let's Encrypt |

---

## 🔒 Dominios y Certificados SSL

### Configuración DNS

Todos los servicios utilizan subdominios de `alonso.servidorgp.somosdelprieto.com`. Es necesario configurar un registro DNS wildcard:

| Tipo | Nombre | Valor |
|------|--------|-------|
| A | `*.alonso.servidorgp` | IP del servidor |

Esto permite que cualquier subdominio (como `grafana.alonso.servidorgp.somosdelprieto.com`) resuelva automáticamente a la IP del servidor.

### Certificados SSL con Let's Encrypt

El contenedor `nginx-proxy-letsencrypt` genera y renueva automáticamente los certificados SSL para cada servicio que tenga configurada la variable `LETSENCRYPT_HOST`.

**Requisitos:**
- El puerto 80 debe ser accesible desde internet (para la validación HTTP-01)
- `LETSENCRYPT_HOST` debe coincidir con `VIRTUAL_HOST`

```yaml
environment:
  - VIRTUAL_HOST=mi-app.alonso.servidorgp.somosdelprieto.com
  - VIRTUAL_PORT=80
  - LETSENCRYPT_HOST=mi-app.alonso.servidorgp.somosdelprieto.com
```

---

## 📊 Monitorización y Métricas

### Servicios de monitorización disponibles

| Servicio | URL | Descripción |
|----------|-----|-------------|
| **Grafana** | `grafana.alonso.servidorgp.somosdelprieto.com` | Dashboards y visualización de métricas |
| **Prometheus** | `prometheus.alonso.servidorgp.somosdelprieto.com` | Base de datos de métricas y consultas |
| **Portainer** | `portainer.alonso.servidorgp.somosdelprieto.com` | Gestión visual de contenedores Docker |

### Métricas recopiladas

**Node Exporter** recoge métricas del sistema host:
- Uso de CPU
- Memoria RAM disponible/usada
- Espacio en disco
- Tráfico de red
- Carga del sistema

### Configurar Grafana

1. Accede a `https://grafana.alonso.servidorgp.somosdelprieto.com`
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

```bash
# Arrancar toda la infraestructura
docker compose up -d

# Arrancar un servicio específico
docker compose up -d grafana
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
3. Accede a Prometheus y verifica los targets: `https://prometheus.alonso.servidorgp.somosdelprieto.com/targets`

#!/bin/bash

# ==========================================
# CONFIGURACIÓN
# ==========================================
ARCHIVO_TRACKER="/opt/plataforma/ultimo_puerto.txt"
PUERTO_INICIAL=8000
RANGO=10
# ==========================================

USUARIO=$1

# 1. Comprobaciones básicas
fi [ -z "$USUARIO" ]; then
    echo "❌ Error: Debes indicar un nombre de usuario."
    echo "Uso: sudo ./crear_usuario.sh nombre_usuario"
    exit 1
fi

if id "$USUARIO" &>/dev/null; then
    echo "❌ Error: El usuario $USUARIO ya existe."
    exit 1
fi

# 2. Calcular el rango de puertos
# Si el archivo no existe, empezamos por el puerto inicial
if [ ! -f "$ARCHIVO_TRACKER" ]; then
    echo $PUERTO_INICIAL > "$ARCHIVO_TRACKER"
fi

PUERTO_START=$(cat "$ARCHIVO_TRACKER")
PUERTO_END=$((PUERTO_START + RANGO - 1))
PROXIMO_PUERTO=$((PUERTO_START + RANGO))

echo "🔧 Configurando usuario: $USUARIO"
echo "👉 Rango de puertos asignado: $PUERTO_START - $PUERTO_END"

# 3. Crear el usuario y añadirlo a Docker
adduser --gecos "" --disabled-password "$USUARIO"
# Le ponemos una contraseña por defecto (puedes cambiarla o pedirla)
echo "$USUARIO:pass1234" | chpasswd
usermod -aG docker "$USUARIO"

# 4. Preparar su entorno (Directorio apps)
HOME_DIR="/home/$USUARIO"
APPS_DIR="$HOME_DIR/apps"

mkdir -p "$APPS_DIR"

# 5. Crear un archivo de información para el usuario
# Esto es CLAVE: Le dejamos un archivo .env o README para que sepa qué puertos usar
FILE_INFO="$APPS_DIR/INFORMACION_IMPORTANTE.txt"

cat <<EOF > "$FILE_INFO"
==================================================
Bienvenido al servidor de despliegue, $USUARIO
==================================================

Tus credenciales:
Usuario: $USUARIO
Rango de Puertos TCP reservados: $PUERTO_START - $PUERTO_END

INSTRUCCIONES:
1. Crea una carpeta para tu app: mkdir ~/apps/mi-app
2. Dentro, crea tu docker-compose.yml.
3. IMPORTANTE: 
   - Si tu app es WEB, NO uses puertos (ports:). Usa la red 'proxy' y las variables VIRTUAL_HOST.
   - Si necesitas exponer una base de datos o servicio extra al host, SOLO puedes usar tus puertos reservados ($PUERTO_START - $PUERTO_END).

Ejemplo de uso de puertos en docker-compose:
    ports:
      - "${PUERTO_START}:3306"

==================================================
EOF

# También creamos un .env global por si quiere usar variables directas
echo "USER_PORT_START=$PUERTO_START" > "$APPS_DIR/.env"
echo "USER_PORT_END=$PUERTO_END" >> "$APPS_DIR/.env"

# 6. Ajustar permisos (El usuario debe ser dueño de su carpeta)
chown -R "$USUARIO:$USUARIO" "$HOME_DIR"
chmod 700 "$HOME_DIR" # Privacidad: otros usuarios no pueden ver su home

# 7. Actualizar el tracker para el siguiente usuario
echo $PROXIMO_PUERTO > "$ARCHIVO_TRACKER"

echo "✅ Usuario creado con éxito."
echo "📂 Info guardada en: $FILE_INFO"
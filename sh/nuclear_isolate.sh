#!/usr/bin/env bash

# =============================================================================
#  NIXAPP NUCLEAR: Aislamiento Total de Home
#  "Todo lo que no está permitido explícitamente, está prohibido/oculto."
# =============================================================================

APP="$1"
REAL_HOME="$HOME"
BASE_VAR_DIR="$REAL_HOME/.var/nixapps"

# 1. VALIDACIÓN
if [[ -z "$APP" ]]; then
    echo "Uso: $(basename "$0") <aplicación> [argumentos...]" >&2
    exit 1
fi

EXECUTABLE=$(command -v "$APP")
if [[ -z "$EXECUTABLE" ]]; then
    echo "Error: '$APP' no encontrado en el PATH." >&2
    exit 1
fi

# 2. PREPARACIÓN DEL ENTORNO AISLADO
APP_DIR="$BASE_VAR_DIR/$APP"
FAKE_HOME="$APP_DIR/home"

# Creamos la estructura básica dentro de .var
mkdir -p "$FAKE_HOME"
mkdir -p "$APP_DIR"/{config,data,cache,state}

# 3. CONSTRUCCIÓN DEL COMANDO BWRAP
# Usamos un array para mantener el código limpio y legible
ARGS=(
    # --- SISTEMA BASE ---
    # Montamos la raíz del sistema como solo lectura (dev-bind para /dev)
    --ro-bind / /
    --dev /dev
    --bind /proc /proc
    --bind /tmp /tmp
    
    # Necesario para NixOS (acceso a binarios y librerías)
    --ro-bind /nix /nix

    # --- EL GRAN ENGAÑO (FAKE HOME) ---
    # Montamos la carpeta vacía de .var ENCIMA de tu ruta real de usuario.
    # La app cree que /home/xardec es esta carpeta vacía.
    --bind "$FAKE_HOME" "$REAL_HOME"
    
    # --- PERSISTENCIA XDG (Opcional pero recomendado para orden dentro del fake home) ---
    # Incluso dentro del fake home, intentamos que usen carpetas ordenadas
    --setenv XDG_CONFIG_HOME "$REAL_HOME/.config"
    --setenv XDG_DATA_HOME   "$REAL_HOME/.local/share"
    --setenv XDG_CACHE_HOME  "$REAL_HOME/.cache"
)

# 4. "PERFORANDO" EL AISLAMIENTO (Allowlist)
# Aquí definimos qué carpetas REALES puede ver la aplicación.
# Se montan desde tu Real Home hacia el Fake Home (en la misma ruta).

VISIBLE_FOLDERS=(
    "Descargas"
    # Añade aquí tus carpetas personalizadas, ej: "Proyectos" o "Code"
)

for FOLDER in "${VISIBLE_FOLDERS[@]}"; do
    if [[ -d "$REAL_HOME/$FOLDER" ]]; then
        # Creamos el punto de montaje en el home falso
        mkdir -p "$FAKE_HOME/$FOLDER"
        # Montamos la carpeta real
        ARGS+=(--bind "$REAL_HOME/$FOLDER" "$REAL_HOME/$FOLDER")
    fi
done

# 5. INTEGRACIÓN DEL SISTEMA (Temas, Fuentes, Configuración Gráfica)
# Como el home está vacío, la app se verá fea (sin temas) a menos que importemos esto.
# Montamos en modo solo lectura (--ro-bind) para que no puedan romper tu config global.

CONFIG_BRIDGES=(
    ".config/gtk-3.0"
    ".config/gtk-4.0"
    ".config/fontconfig"
    ".icons"
    ".fonts"
    ".themes"
    ".local/share/fonts"
    ".local/share/icons"
    ".Xauthority" # Necesario para X11
)

for CONF in "${CONFIG_BRIDGES[@]}"; do
    if [[ -e "$REAL_HOME/$CONF" ]]; then
        # Replicamos la estructura de directorios en el fake home
        DIR_NAME=$(dirname "$CONF")
        mkdir -p "$FAKE_HOME/$DIR_NAME"
        
        # Montamos el archivo/carpeta
        ARGS+=(--ro-bind "$REAL_HOME/$CONF" "$REAL_HOME/$CONF")
    fi
done

# 6. INTEGRACIÓN DE HARDWARE/SOCKETS (Wayland/Pulseaudio/Pipewire)
# Esto es vital para que las apps gráficas funcionen
ARGS+=(
    --ro-bind-try "/run/user/$UID" "/run/user/$UID"
    --setenv XDG_RUNTIME_DIR "/run/user/$UID"
)

# 7. EJECUCIÓN
echo ":: Ejecutando '$APP' en entorno nuclear..." >&2
exec bwrap "${ARGS[@]}" "$EXECUTABLE" "${@:2}"

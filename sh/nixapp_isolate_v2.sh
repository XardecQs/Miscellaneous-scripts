#!/usr/bin/env bash
# =============================================================================
# NIXAPP OVERLAYFS: Solución definitiva con persistencia y acceso al home real
# =============================================================================
set -euo pipefail

APP="$1"
REAL_HOME="$HOME"
BASE_VAR_DIR="$REAL_HOME/.var/nixapps"

# =============================================================================
# 1. VALIDACIÓN
# =============================================================================
if [[ -z "${APP:-}" ]]; then
    echo "Uso: $(basename "$0") <aplicación> [argumentos...]" >&2
    exit 1
fi

EXECUTABLE=$(command -v "$APP" 2>/dev/null || true)
if [[ -z "$EXECUTABLE" ]]; then
    echo "Error: '$APP' no encontrado en el PATH." >&2
    exit 1
fi

# =============================================================================
# 2. PREPARACIÓN DE DIRECTORIOS OVERLAYFS
# =============================================================================
APP_DIR="$BASE_VAR_DIR/$APP"
LOWER_DIR="$REAL_HOME"                    # Capa base (tu home real, solo lectura)
UPPER_DIR="$APP_DIR/upper"               # Cambios de la aplicación
WORK_DIR="$APP_DIR/work"                 # Directorio de trabajo de overlayfs
MERGED_DIR="$APP_DIR/merged"             # Vista combinada final

# Crear estructura de directorios
mkdir -p "$UPPER_DIR" "$WORK_DIR" "$MERGED_DIR"

# Directorios XDG específicos para persistencia
mkdir -p "$APP_DIR"/{config,data,cache,state}

# =============================================================================
# 3. MONTAJE OVERLAYFS
# =============================================================================
# Montar el overlay que combina home real + cambios aislados
sudo mount -t overlay overlay -o \
    "lowerdir=$LOWER_DIR,upperdir=$UPPER_DIR,workdir=$WORK_DIR" \
    "$MERGED_DIR"

# Función de limpieza al salir
cleanup() {
    echo ":: Desmontando overlay..." >&2
    sudo umount "$MERGED_DIR"
    exit 0
}
trap cleanup EXIT INT TERM

# =============================================================================
# 4. CONFIGURACIÓN BWRAP PARA REDIRECCIONES XDG
# =============================================================================
ARGS=(
    # Sistema base
    --ro-bind / / 
    --dev /dev
    --proc /proc
    --tmpfs /tmp
    
    # Nix store
    --ro-bind /nix /nix
    
    # Overlay como HOME
    --bind "$MERGED_DIR" "$REAL_HOME"
    
    # Redirecciones XDG (prioridad sobre el overlay)
    --bind "$APP_DIR/config" "$REAL_HOME/.config"
    --bind "$APP_DIR/data"   "$REAL_HOME/.local/share" 
    --bind "$APP_DIR/cache"  "$REAL_HOME/.cache"
    --bind "$APP_DIR/state"  "$REAL_HOME/.local/state"
    
    # Variables de entorno
    --setenv HOME "$REAL_HOME"
    --setenv XDG_CONFIG_HOME "$REAL_HOME/.config"
    --setenv XDG_DATA_HOME "$REAL_HOME/.local/share"
    --setenv XDG_CACHE_HOME "$REAL_HOME/.cache"
    --setenv XDG_STATE_HOME "$REAL_HOME/.local/state"
)

# =============================================================================
# 5. EJECUCIÓN
# =============================================================================
echo ":: Ejecutando '$APP' en entorno aislado (OverlayFS)..." >&2
echo ":: Los cambios se guardarán en: $APP_DIR/upper" >&2

exec bwrap "${ARGS[@]}" --new-session "$EXECUTABLE" "${@:2}"
#!/usr/bin/env bash
# =============================================================================
#  NIXAPP: Sistema de Aislamiento de Configuración para NixOS
#  "Mantén tu $HOME limpio, al estilo NixOS"
#
#  Este script permite ejecutar aplicaciones con acceso completo a tu $HOME,
#  pero redirigiendo toda su configuración a ~/.var/nixapps/$APP
# =============================================================================

set -euo pipefail

APP="$1"
REAL_HOME="$HOME"
BASE_VAR_DIR="$REAL_HOME/.var/nixapps"

# =============================================================================
# 1. VALIDACIÓN
# =============================================================================

if [[ -z "${APP:-}" ]]; then
    cat >&2 <<EOF
Uso: $(basename "$0") <aplicación> [argumentos...]

Ejemplo:
  $(basename "$0") firefox
  $(basename "$0") nvim prueba.txt

Variables de entorno:
  NIXAPP_DEBUG=1    Mostrar información de debug

Cómo funciona:
  - La aplicación puede ver y acceder a todos tus archivos en $HOME
  - Toda configuración (.config, .local/share, .cache) se guarda en:
    ~/.var/nixapps/\$APP/
  - Tu $HOME real permanece limpio
EOF
    exit 1
fi

EXECUTABLE=$(command -v "$APP" 2>/dev/null || true)
if [[ -z "$EXECUTABLE" ]]; then
    echo "Error: '$APP' no encontrado en el PATH." >&2
    exit 1
fi

# =============================================================================
# 2. PREPARACIÓN DE DIRECTORIOS
# =============================================================================

APP_DIR="$BASE_VAR_DIR/$APP"

# Directorios donde se almacenarán las configuraciones
CONFIG_UPPER="$APP_DIR/config"
DATA_UPPER="$APP_DIR/data"
CACHE_UPPER="$APP_DIR/cache"
STATE_UPPER="$APP_DIR/state"

# Directorios de trabajo para overlayfs (requeridos por el kernel)
CONFIG_WORK="$APP_DIR/.work/config"
DATA_WORK="$APP_DIR/.work/data"
CACHE_WORK="$APP_DIR/.work/cache"
STATE_WORK="$APP_DIR/.work/state"

# Crear toda la estructura necesaria
mkdir -p "$CONFIG_UPPER" "$CONFIG_WORK"
mkdir -p "$DATA_UPPER" "$DATA_WORK"
mkdir -p "$CACHE_UPPER" "$CACHE_WORK"
mkdir -p "$STATE_UPPER" "$STATE_WORK"

# Crear directorios reales de XDG si no existen
mkdir -p "$REAL_HOME/.config"
mkdir -p "$REAL_HOME/.local/share"
mkdir -p "$REAL_HOME/.cache"
mkdir -p "$REAL_HOME/.local/state"

# =============================================================================
# 3. CONSTRUCCIÓN DEL COMANDO BWRAP CON OVERLAYFS
# =============================================================================

# ESTRATEGIA CLAVE:
# 1. Bindear todo el $HOME primero (acceso completo a archivos)
# 2. Luego montar overlays sobre los directorios XDG (estas monturas
#    "enmascaran" los originales gracias al orden de ejecución de bwrap)
# 3. Resultado: la app ve todo tu home, pero escribe config en su propio espacio

ARGS=(
    # --- SISTEMA BASE (Solo Lectura) ---
    --ro-bind / /
    --dev /dev
    --proc /proc
    --tmpfs /tmp
    
    # NixOS: Acceso al store
    --ro-bind /nix /nix
    
    # --- HOME COMPLETO (Lectura/Escritura) ---
    # PRIMERO: Dar acceso RW completo al home
    --bind "$REAL_HOME" "$REAL_HOME"
    
    # --- OVERLAYS PARA DIRECTORIOS XDG ---
    # DESPUÉS: Montar overlays que "enmascaran" los dirs XDG originales
    # Sintaxis: --overlay-src LOWER --overlay UPPER WORKDIR DEST
    
    # .config: lee de $HOME/.config real, escribe en ~/.var/nixapps/$APP/config
    --overlay-src "$REAL_HOME/.config"
    --overlay "$CONFIG_UPPER" "$CONFIG_WORK" "$REAL_HOME/.config"
    
    # .local/share
    --overlay-src "$REAL_HOME/.local/share"
    --overlay "$DATA_UPPER" "$DATA_WORK" "$REAL_HOME/.local/share"
    
    # .cache
    --overlay-src "$REAL_HOME/.cache"
    --overlay "$CACHE_UPPER" "$CACHE_WORK" "$REAL_HOME/.cache"
    
    # .local/state
    --overlay-src "$REAL_HOME/.local/state"
    --overlay "$STATE_UPPER" "$STATE_WORK" "$REAL_HOME/.local/state"
    
    # --- VARIABLES DE ENTORNO XDG ---
    --setenv HOME "$REAL_HOME"
    --setenv XDG_CONFIG_HOME "$REAL_HOME/.config"
    --setenv XDG_DATA_HOME "$REAL_HOME/.local/share"
    --setenv XDG_CACHE_HOME "$REAL_HOME/.cache"
    --setenv XDG_STATE_HOME "$REAL_HOME/.local/state"
)

# =============================================================================
# 4. MODO DEBUG
# =============================================================================

if [[ "${NIXAPP_DEBUG:-0}" == "1" ]]; then
    cat >&2 <<EOF
=== NIXAPP DEBUG ===
App: $APP
Ejecutable: $EXECUTABLE
Directorio aislado: $APP_DIR

Overlays activos (lower -> upper):
  .config      : $REAL_HOME/.config -> $CONFIG_UPPER
  .local/share : $REAL_HOME/.local/share -> $DATA_UPPER
  .cache       : $REAL_HOME/.cache -> $CACHE_UPPER
  .local/state : $REAL_HOME/.local/state -> $STATE_UPPER

La aplicación:
  ✓ PUEDE ver y editar todos tus archivos en $HOME
  ✓ PUEDE ver configuraciones existentes en los dirs XDG
  ✓ ESCRIBE nueva configuración en: $APP_DIR
  ✓ NO modifica tu $HOME real

Inspeccionar configuración guardada:
  ls -la $APP_DIR

Comando bwrap completo:
  bwrap ${ARGS[*]} $EXECUTABLE
===================
EOF
fi

# =============================================================================
# 5. EJECUCIÓN
# =============================================================================

exec bwrap "${ARGS[@]}" "$EXECUTABLE" "${@:2}"

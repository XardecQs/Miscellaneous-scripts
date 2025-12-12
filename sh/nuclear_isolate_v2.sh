#!/usr/bin/env bash

# =============================================================================
#  NIXAPP NUCLEAR V2: Aislamiento Total con Persistencia XDG
#  "El orden de NixOS para tu $HOME"
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
# 2. PREPARACIÓN DE ESTRUCTURA DE DIRECTORIOS
# =============================================================================

APP_DIR="$BASE_VAR_DIR/$APP"
FAKE_HOME="$APP_DIR/home"

# Estructura completa según XDG Base Directory Specification
mkdir -p "$FAKE_HOME"
mkdir -p "$APP_DIR"/{config,data,cache,state,tmp,run}

# Crear estructura de directorios estándar dentro del fake home
mkdir -p "$FAKE_HOME"/{.config,.local/share,.cache,.local/state}

# =============================================================================
# 3. CONSTRUCCIÓN DEL COMANDO BWRAP
# =============================================================================

ARGS=(
    # --- SISTEMA BASE (Solo Lectura) ---
    #
    --ro-bind / /
    --dev /dev
    --proc /proc
    --bind /tmp /tmp
    
    # NixOS: Acceso al store
    --ro-bind /nix /nix
    
    # --- TEMPORAL AISLADO ---
    --bind "$APP_DIR/tmp" /tmp
    
    # --- EL GRAN ENGAÑO: FAKE HOME ---
    # La app ve $HOME como una carpeta vacía controlada
    --bind "$FAKE_HOME" "$REAL_HOME"
    
    # --- PERSISTENCIA XDG (montados DENTRO del fake home) ---
    # Aquí está la magia: montamos los directorios de $APP_DIR
    # en las rutas que la app espera ver dentro de su "home"
    --bind "$APP_DIR/config" "$REAL_HOME/.config"
    --bind "$APP_DIR/data"   "$REAL_HOME/.local/share"
    --bind "$APP_DIR/cache"  "$REAL_HOME/.cache"
    --bind "$APP_DIR/state"  "$REAL_HOME/.local/state"
    
    # Variables de entorno XDG (para apps que las respeten)
    --setenv HOME "$REAL_HOME"  # Dentro del namespace
    --setenv XDG_CONFIG_HOME "$REAL_HOME/.config"
    --setenv XDG_DATA_HOME   "$REAL_HOME/.local/share"
    --setenv XDG_CACHE_HOME  "$REAL_HOME/.cache"
    --setenv XDG_STATE_HOME  "$REAL_HOME/.local/state"
)

# =============================================================================
# 4. ALLOWLIST: CARPETAS VISIBLES DEL HOME REAL
# =============================================================================

VISIBLE_FOLDERS=(
    "Descargas"
    "Documentos"
    "Imágenes"
    "Vídeos"
    "Música"
    # Añade tus carpetas: "Proyectos" "Code" etc.
)

for FOLDER in "${VISIBLE_FOLDERS[@]}"; do
    if [[ -d "$REAL_HOME/$FOLDER" ]]; then
        mkdir -p "$FAKE_HOME/$FOLDER"
        ARGS+=(--bind "$REAL_HOME/$FOLDER" "$REAL_HOME/$FOLDER")
    fi
done

# =============================================================================
# 7. MODO DEBUG (Variable de entorno)
# =============================================================================

if [[ "${NIXAPP_DEBUG:-0}" == "1" ]]; then
    echo "=== DEBUG: Configuración de Aislamiento ===" >&2
    echo "App: $APP" >&2
    echo "Ejecutable: $EXECUTABLE" >&2
    echo "Fake Home: $FAKE_HOME" >&2
    echo "App Dir: $APP_DIR" >&2
    echo "=========================================" >&2
fi

# =============================================================================
# 8. EJECUCIÓN
# =============================================================================

echo ":: Ejecutando '$APP' en entorno aislado..." >&2

# Opción: usa --new-session para mayor aislamiento de procesos
exec bwrap "${ARGS[@]}" --new-session "$EXECUTABLE" "${@:2}"

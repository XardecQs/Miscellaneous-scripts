#!/usr/bin/env bash

set -euo pipefail

APP="$1"
REAL_HOME="$HOME"
BASE_VAR_DIR="$REAL_HOME/.var/nixapps"
APP_DIR="$BASE_VAR_DIR/$APP"
FAKE_HOME="$APP_DIR/home"

if [[ -z "${APP:-}" ]]; then
    echo "Uso: $(basename "$0") <aplicación> [argumentos...]" >&2
    exit 1
fi
EXECUTABLE=$(command -v "$APP" 2>/dev/null || true)
if [[ -z "$EXECUTABLE" ]]; then
    echo "Error: '$APP' no encontrado en el PATH." >&2
    exit 1
fi

mkdir -p "$FAKE_HOME"
mkdir -p "$APP_DIR"/{config,data,cache,state,tmp,run}
mkdir -p "$FAKE_HOME"/{.config,.local/share,.cache,.local/state}
ARGS=(
    --ro-bind / /
    --dev /dev
    --proc /proc
    --bind /tmp /tmp
    --ro-bind /nix /nix
    --bind "$APP_DIR/tmp" /tmp
    --bind "$FAKE_HOME" "$REAL_HOME"
    --bind "$APP_DIR/config" "$REAL_HOME/.config"
    --bind "$APP_DIR/data"   "$REAL_HOME/.local/share"
    --bind "$APP_DIR/cache"  "$REAL_HOME/.cache"
    --bind "$APP_DIR/state"  "$REAL_HOME/.local/state"
    --setenv HOME "$REAL_HOME"  
    --setenv XDG_CONFIG_HOME "$APP_DIR/config"
    --setenv XDG_DATA_HOME   "$APP_DIR/data"
    --setenv XDG_CACHE_HOME  "$APP_DIR/cache"
    --setenv XDG_STATE_HOME  "$APP_DIR/state"
)

VISIBLE_FOLDERS=(
    "Descargas"
    "Documentos"
)
for FOLDER in "${VISIBLE_FOLDERS[@]}"; do
    if [[ -d "$REAL_HOME/$FOLDER" ]]; then
        mkdir -p "$FAKE_HOME/$FOLDER"
        ARGS+=(--bind "$REAL_HOME/$FOLDER" "$REAL_HOME/$FOLDER")
    fi
done
if [[ "${NIXAPP_DEBUG:-0}" == "0" ]]; then
    echo "=== DEBUG: Configuración de Aislamiento ===" >&2
    echo "App: $APP" >&2
    echo "Ejecutable: $EXECUTABLE" >&2
    echo "Fake Home: $FAKE_HOME" >&2
    echo "App Dir: $APP_DIR" >&2
    echo "=========================================" >&2
fi
echo ":: Ejecutando '$APP' en entorno aislado..." >&2
exec bwrap "${ARGS[@]}" --new-session "$EXECUTABLE" "${@:2}"

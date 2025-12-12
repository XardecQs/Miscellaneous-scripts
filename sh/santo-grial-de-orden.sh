#!/usr/bin/env bash

# === CONFIGURACIÓN ===
APP="$1"
BASE_VAR_DIR="$HOME/.var/nixapps"
REAL_HOME="$HOME"

# === VALIDACIONES ===
if [[ -z "$APP" ]]; then
  echo "Uso: $(basename "$0") <nombre_binario>" >&2
  exit 1
fi

EXECUTABLE=$(command -v "$APP")
if [[ -z "$EXECUTABLE" ]]; then
  echo "Error: No se encontró el ejecutable '$APP' en el PATH." >&2
  exit 1
fi

# === PREPARACIÓN DE DIRECTORIOS (Estilo Flatpak) ===
APP_DIR="$BASE_VAR_DIR/$APP"
##mkdir -p "$APP_DIR"
mkdir -p "$APP_DIR"/{config,data,cache,state}
# === SYMLINKS DE SISTEMA (Opcional pero recomendado) ===
# Muchas apps necesitan ver temas GTK, cursores o fuentes que viven en tu config real.
# Enlaza lo esencial para que la app no se vea "fea" o rota.
# Si el directorio de destino ya existe, no lo sobreescribimos.
## ln -s "$REAL_HOME/.config/gtk-3.0" "$APP_DIR/config/gtk-3.0" 2>/dev/null
## ln -s "$REAL_HOME/.config/gtk-4.0" "$APP_DIR/config/gtk-4.0" 2>/dev/null
## ln -s "$REAL_HOME/.icons" "$APP_DIR/data/icons" 2>/dev/null
## ln -s "$REAL_HOME/.fonts" "$APP_DIR/data/fonts" 2>/dev/null

# === EJECUCIÓN CON BUBBLEWRAP ===
# Explicación de los flags:
# --dev-bind / /  -> Monta la raíz del sistema (necesario para ver /nix/store).
# --bind /home /home -> IMPORTANTE: Monta tu home REAL. La app puede ver y editar tus documentos.
# --setenv ... -> Aquí ocurre la magia. Redirigimos donde la app ESCRIBE sus configs.

bwrap \
  --dev-bind / / \
  --dev-bind /dev /dev \
  --bind /proc /proc \
  --bind /tmp /tmp \
  --bind "$REAL_HOME" "$REAL_HOME" \
  --setenv XDG_CONFIG_HOME "$APP_DIR/config" \
  --setenv XDG_DATA_HOME   "$APP_DIR/data" \
  --setenv XDG_CACHE_HOME  "$APP_DIR/cache" \
  --setenv XDG_STATE_HOME  "$APP_DIR/state" \
  --new-session \
  "$EXECUTABLE" "${@:2}" # Pasa el resto de argumentos a la app

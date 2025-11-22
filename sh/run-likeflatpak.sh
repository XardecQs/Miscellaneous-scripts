#!/usr/bin/env bash
# run-with-overlay-home  →  la versión definitiva que buscabas

set -euo pipefail

CMD="${1:-}"
[ -z "$CMD" ] && { echo "Uso: $0 <comando> [args...]"; exit 1; }

BIN="$(command -v "$CMD")"
[ -z "$BIN" ] && { echo "Comando $CMD no encontrado"; exit 1; }

APP_NAME="$(basename "$CMD")"
BASE="$HOME/.var/nixapps"
OVERLAY="$BASE/$APP_NAME-overlay"

# Carpetas necesarias para overlayfs
mkdir -p "$OVERLAY"/{upper,work,merged}

# Monta el overlay (solo la primera vez o si se desmontó)
#if ! mountpoint -q "$OVERLAY/merged"; then
#  mount -t overlay overlay \
#    -o lowerdir="$HOME",upperdir="$OVERLAY/upper",workdir="$OVERLAY/work" \
#    "$OVERLAY/merged"
#fi

# Lanzamos la app con el home falso
exec bwrap \
  --ro-bind /nix/store /nix/store \
  --ro-bind /usr /usr \
  --dev /dev \
  --proc /proc \
  --bind /sys /sys \
  --ro-bind /etc /etc \
  --tmpfs /tmp \
  --bind "$OVERLAY/merged" "$HOME" \   # ← aquí está la magia
  --setenv HOME "$HOME" \
  --chdir "$HOME" \
  --die-with-parent \
  "$BIN" "${@:2}"

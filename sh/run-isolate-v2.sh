#!/usr/bin/env bash

APP="$1"
HOME="$HOME"
DIRECTORY="$HOME/.var/isolate"

# Verificar que se haya proporcionado un nombre de aplicación
if [[ -z "$APP" ]]; then
  echo "Uso: $0 <nombre_de_la_aplicación>" >&2
  exit 1
fi

# Crear el directorio privado si no existe
if [[ ! -d "$DIRECTORY/$APP" ]]; then
  mkdir -p "$DIRECTORY/$APP" || { echo "Error al crear el directorio." >&2; exit 1; }
fi

# Buscar la ruta del ejecutable de forma más fiable
EXECUTABLE=$(whereis $APP | awk '{print $2}')
if [[ -z "$EXECUTABLE" ]]; then
  echo "Error: no se encontró el ejecutable para '$APP'." >&2
  exit 1
fi

# Ejecutar con firejail
firejail --private="$DIRECTORY/$APP" --allusers "$EXECUTABLE"

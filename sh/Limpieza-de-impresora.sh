#!/bin/bash

# Verifica si el usuario especificó el número de repeticiones
if [ -z "$1" ]; then
  echo "Uso: $0 <cantidad_de_limpiezas>"
  exit 1
fi

# Cantidad de limpiezas
CANTIDAD=$1
DISPOSITIVO="/dev/usb/lp0"

# Verifica que escputil esté instalado
if ! command -v escputil &> /dev/null; then
  echo "El comando escputil no está instalado. Instálalo con: sudo pacman -S gutenprint"
  exit 1
fi

# Verifica que el dispositivo exista
if [ ! -e "$DISPOSITIVO" ]; then
  echo "No se encontró el dispositivo en $DISPOSITIVO. Asegúrate de que la impresora esté conectada."
  exit 1
fi

# Realiza la limpieza de cabezales
echo "Iniciando limpieza de cabezales $CANTIDAD veces..."
for ((i = 1; i <= CANTIDAD; i++)); do
  echo "Limpieza #$i..."
  sudo escputil -c -r "$DISPOSITIVO"
  if [ $? -ne 0 ]; then
    echo "Error durante la limpieza #$i. Saliendo..."
    exit 1
  fi
  sleep 160 # Espera 5 segundos entre cada limpieza
done

# Imprime una prueba de inyectores
echo "Imprimiendo prueba de inyectores..."
sudo escputil -n -r "$DISPOSITIVO"

echo "Proceso completo."


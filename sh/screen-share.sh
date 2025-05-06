#!/bin/bash
# Script para automatizar la creación/remoción de pantalla virtual en Hyprland
# xavier 27/04/25

SCREEN_NAME="FakeScreen"

cleanup() {
    echo "Removiendo $SCREEN_NAME..."
    hyprctl output remove "$SCREEN_NAME" >/dev/null 2>&1
}

trap cleanup EXIT

echo "Creando pantalla virtual '$SCREEN_NAME'..."
if ! hyprctl output create auto "$SCREEN_NAME" >/dev/null 2>&1; then
    echo "Error: No se pudo crear la pantalla virtual" >&2
    exit 1
fi

case "$1" in
    gnd)
        gnome-network-displays
        ;;
    weylus)
        weylus --auto-start
        ;;
    *)
        echo "Uso: $0 [gnd|weylus]"
        exit 1  
        ;;
esac


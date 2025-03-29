#!/bin/bash

# Paquetes necesarios (instalar con yay/pacman):
# grim slurp wl-clipboard tesseract tesseract-data-eng zenity libnotify

function show_error_dialog {
    zenity --error --text "$1" --width=300
    exit 1
}

# Tomar captura de la región seleccionada
capture_file="/tmp/screenshot-$(date +%s).png"
grim -g "$(slurp -d)" "$capture_file" || show_error_dialog "Error al capturar la región o cancelado por el usuario"

# Extraer texto con OCR (agrega -l spa para español, requiere tesseract-data-spa)
tesseract "$capture_file" /tmp/extracted_text -l spa 2>/dev/null || show_error_dialog "Error al procesar OCR"

# Copiar al portapapeles y notificar
wl-copy < /tmp/extracted_text.txt || show_error_dialog "Error al coprar al portapapeles"
notify-send -a "OCR Tool" "Texto copiado" "El texto reconocido se ha copiado al portapapeles" -i edit-paste

# Limpiar archivos temporales
rm "$capture_file" /tmp/extracted_text.txt
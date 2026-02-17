#!/usr/bin/env bash

# Verificar dependencias
if ! command -v identify &> /dev/null; then
    echo "Error: Necesitas instalar ImageMagick (sudo pacman -S imagemagick)"
    exit 1
fi

tmp_file=$(mktemp)

function obtener_directorio {
    local nombre=$1
    local archivo=$2
    local directorio=""
    local dimensions

    # Verificar primero si es imagen (incluyendo GIFs)
    if dimensions=$(identify -format "%w %h" "$archivo[0]" 2>/dev/null); then
        width=$(echo $dimensions | awk '{print $1}')
        height=$(echo $dimensions | awk '{print $2}')
        
        # Calcular relación de aspecto
        if [ $width -gt $height ]; then
            directorio="horizontal"
        elif [ $height -gt $width ]; then
            directorio="vertical"
        else
            directorio="1-1"
        fi
    else
        # Lógica para no-imágenes
        nombre_procesado="${nombre#.}"  # Quitar punto inicial si es oculto
        
        # Manejo mejorado de extensiones compuestas
        if [[ "$nombre_procesado" =~ ^..*\. ]]; then
            case "$nombre_procesado" in
                *.tar.gz|*.tar.bz2|*.tar.xz)
                    directorio=$(echo "$nombre_procesado" | rev | cut -d. -f1-2 | rev)
                    ;;
                *)
                    directorio="${nombre_procesado##*.}"
                    ;;
            esac
        fi
        
        directorio="${directorio:-sin_extension}"
        directorio=$(echo "$directorio" | tr '[:upper:]' '[:lower:]')
    fi

    echo "$directorio"
}

find . -maxdepth 1 -type f -print0 | while IFS= read -r -d '' archivo; do
    nombre=$(basename "$archivo")
    directorio=$(obtener_directorio "$nombre" "$archivo")

    # Crear directorio si no existe
    mkdir -p "./$directorio" 2>/dev/null && echo "$directorio" >> "$tmp_file"
    
    # Mover archivo con verificación
    if ! mv -f "$archivo" "./$directorio/" 2>/dev/null; then
        echo "Error moviendo: $(printf "%q" "$archivo")" >&2
    fi
done

echo -e "\nOrganización completada. Directorios creados:"
sort -u "$tmp_file" | sed 's/^/- /'
rm "$tmp_file"

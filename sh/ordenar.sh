#!/usr/bin/env bash

tmp_file=$(mktemp)  # Archivo temporal para directorios creados

function obtener_directorio {
    local nombre=$1
    local directorio=""

    if [[ "$nombre" == *.* ]]; then
        ultima_ext="${nombre##*.}"
        directorio="$ultima_ext"

        # Manejar extensiones compuestas
        case "$ultima_ext" in
            "gz"|"bz2"|"xz")
                if [[ "$nombre" == *.*.* ]]; then
                    nombre_sin_ext="${nombre%.*}"
                    penultima_ext="${nombre_sin_ext##*.}"
                    directorio="$penultima_ext.$ultima_ext"
                fi
                ;;
        esac
    fi

    # Normalizar a minúsculas y asignar "sin_extension" si es necesario
    directorio=$(echo "${directorio:-sin_extension}" | tr '[:upper:]' '[:lower:]')
    echo "$directorio"
}

find . -maxdepth 1 -type f -print0 | while IFS= read -r -d '' archivo; do
    nombre=$(basename "$archivo")
    nombre_procesado="$nombre"

    # Manejar archivos ocultos
    if [[ "$nombre" =~ ^\. ]]; then
        nombre_procesado="${nombre#.}"
    fi

    directorio=$(obtener_directorio "$nombre_procesado")

    # Crear directorio si no existe y registrarlo
    if [[ ! -d "./$directorio" ]]; then
        mkdir -p "./$directorio"
        echo "$directorio" >> "$tmp_file"
    fi

    # Mover archivo con manejo de errores
    if ! mv -f "$archivo" "./$directorio/"; then
        echo "Error al mover: $(printf "%q" "$archivo")" >&2
    fi
done

echo -e "\nOrganización completada. Directorios creados:"
sort -u "$tmp_file" | sed 's/^/- /'
rm "$tmp_file"

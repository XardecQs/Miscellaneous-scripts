#!/bin/bash

function obtener_directorio {
    local nombre=$1
    local directorio=""

    if [[ "$nombre" == *.* ]]; then
        directorio="${nombre##*.}"  # Última extensión

        # Manejar extensiones compuestas conocidas
        case "$directorio" in
            "gz"|"bz2"|"xz")
                if [[ "$nombre" == *.*.* ]]; then
                    # Obtener penúltima extensión
                    nombre_sin_ultima_ext="${nombre%.*}"
                    penultima_ext="${nombre_sin_ultima_ext##*.}"
                    directorio="$penultima_ext.$directorio"
                fi
                ;;
        esac
    fi

    # Si no hay extensión o está vacía, usar "sin_extension"
    echo "${directorio:-sin_extension}"
}

find . -maxdepth 1 -type f -print0 | while IFS= read -r -d '' archivo; do
    nombre=$(basename "$archivo")
    directorio=""

    if [[ "$nombre" =~ ^\. ]]; then  # Archivo oculto
        nombre_sin_punto="${nombre#.}"  # Eliminar el punto inicial
        directorio=$(obtener_directorio "$nombre_sin_punto")
    else  # Archivo normal
        directorio=$(obtener_directorio "$nombre")
    fi

    # Limpieza por si la extensión es vacía (ej: archivo.)
    [[ -z "$directorio" ]] && directorio="sin_extension"

    # Mover el archivo
    mkdir -p "./$directorio"
    mv -f "$archivo" "./$directorio/" &>/dev/null
done

echo "Organización completada. Archivos clasificados en:"
find . -type d -not -path '.' | sed 's/^\.\///'
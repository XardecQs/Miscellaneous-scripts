#!/bin/bash

# Script para mover archivos de subdirectorios al directorio actual
# con control de profundidad y manejo de colisiones

# Configuración
declare -i max_profundidad=2  # Profundidad máxima por defecto (directorios inmediatos)
modo_colision="rename"        # Opciones: overwrite, skip, rename
eliminar_directorios_vacios=true

# Preguntar profundidad si no se especifica como argumento
if [ "$1" ]; then
    max_profundidad=$1
else
    read -p "Profundidad máxima a buscar (0=solo actual): " max_profundidad
fi

# Validar entrada
if [ $max_profundidad -lt 0 ]; then
    echo "Error: La profundidad no puede ser negativa"
    exit 1
fi

# Ajustar parámetros find
if [ $max_profundidad -eq 0 ]; then
    find_depth="-maxdepth 0"
else
    find_depth="-maxdepth $max_profundidad"
fi

# Encontrar y mover archivos
find . -type f $find_depth -print0 | while IFS= read -r -d '' archivo; do
    # Saltar archivos en el directorio raíz
    if [[ "$archivo" != */* ]]; then
        continue
    fi
    
    nombre_base=$(basename "$archivo")
    contador=1
    
    # Manejar colisiones de nombres
    while [ -e "./$nombre_base" ]; do
        case $modo_colision in
            "overwrite")
                break
                ;;
            "skip")
                continue 2
                ;;
            "rename")
                nombre_base="${nombre_base%.*}_$contador.${nombre_base##*.}"
                ((contador++))
                ;;
        esac
    done
    
    # Mover el archivo
    mv -fv "$archivo" "./$nombre_base"
done

# Eliminar directorios vacíos si está habilitado
if [ "$eliminar_directorios_vacios" = true ]; then
    find . -type d -empty -delete
fi

echo "Operación completada. Archivos movidos al directorio: $(pwd)"|
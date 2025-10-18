#!/usr/bin/env bash

find . -type f | while IFS= read -r file; do
    dirname="${file%/*}"
    basename="${file##*/}"
    
    # Si está en directorio raíz, ajustar dirname
    [ "$dirname" = "$file" ] && dirname="."
    
    name_no_ext="${basename%.*}"
    ext="${basename##*.}"
    
    # Evitar renombrar si ya tiene el formato
    case "$basename" in
        "${name_no_ext}_${name_no_ext}.${ext}"*) continue ;;
        "${name_no_ext}_${name_no_ext}") continue ;;
    esac
    
    # Solo agregar extensión si existe
    if [ "$name_no_ext" != "$basename" ]; then
        newname="$dirname/${name_no_ext}_${name_no_ext}.$ext"
    else
        newname="$dirname/${name_no_ext}_${name_no_ext}"
    fi
    
    # Solo renombrar si el archivo destino no existe
    if [ ! -e "$newname" ]; then
        echo mv "$file" "$newname"
    else
        echo "# Skipped: $newname already exists" >&2
    fi
done

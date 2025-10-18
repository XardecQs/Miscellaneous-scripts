#!/usr/bin/env bash
# Script para mover archivos de subdirectorios al directorio actual
# con control de profundidad, exclusiones y manejo de colisiones

# Configuración
declare -i max_profundidad=2
modo_colision="rename"        # Opciones: overwrite, skip, rename
eliminar_directorios_vacios=true
exclude_dirs=(".stfolder" "node_modules")  # Carpetas excluídas

# Verificar que no se ejecute como root
if [ "$(id -u)" -eq 0 ]; then
    echo "Error: No se permite ejecutar este script como root" >&2
    exit 1
fi

# Verificar que no estemos en el directorio raíz del sistema
if [ "$(pwd)" = "/" ]; then
    echo "Error: No se puede ejecutar en el directorio raíz del sistema" >&2
    exit 1
fi

# Obtener profundidad
if [ "$1" ]; then
    if ! [[ "$1" =~ ^[0-9]+$ ]] || [ "$1" -lt 0 ]; then
        echo "Error: La profundidad debe ser un número entero no negativo" >&2
        exit 1
    fi
    max_profundidad=$1
else
    read -p "Profundidad máxima a buscar (0=subdirectorios inmediatos): " max_profundidad
    until [[ "$max_profundidad" =~ ^[0-9]+$ ]]; do
        read -p "Ingrese un número válido: " max_profundidad
    done
fi

# Ajustar parámetros find
if [ $max_profundidad -eq 0 ]; then
    find_depth="-mindepth 1 -maxdepth 1"  # Solo subdirectorios inmediatos
else
    find_depth="-maxdepth $((max_profundidad + 1))"
fi

# Construir exclusiones para find
exclude_args=()
for dir in "${exclude_dirs[@]}"; do
    exclude_args+=(-path "./$dir" -prune -o)
done

# Encontrar y mover archivos
echo "Excluyendo carpetas: ${exclude_dirs[*]}"
find . $find_depth "${exclude_args[@]}" -type f -print0 | while IFS= read -r -d '' archivo; do
    # Excluir archivos en directorio actual cuando profundidad es 0
    if [[ "$archivo" == ./$(basename "$archivo") ]]; then
        continue
    fi

    nombre_base=$(basename "$archivo")
    contador=1
    
    # Manejar nombres ocultos (conservar el punto inicial)
    if [[ "$nombre_base" == .* ]]; then
        base=".${nombre_base#.}"  # Extrae todo después del primer punto
        tiene_punto_inicial=true
    else
        base="$nombre_base"
        tiene_punto_inicial=false
    fi

    destino="./$nombre_base"
    
    # Manejar colisiones
    while [ -e "$destino" ]; do
        case $modo_colision in
            "overwrite") break ;;
            "skip") continue 2 ;;
            "rename")
                extension="${base##*.}"
                nombre_sin_ext="${base%.*}"
                
                # Caso especial para archivos ocultos sin extensión
                if [ "$tiene_punto_inicial" = true ] && [ "$extension" = "$base" ]; then
                    nuevo_nombre=".${nombre_sin_ext}_$contador"
                elif [ "$nombre_sin_ext" = "$base" ]; then
                    nuevo_nombre="${base}_$contador"
                else
                    nuevo_nombre="${nombre_sin_ext}_$contador.${extension}"
                fi
                
                destino="./$nuevo_nombre"
                ((contador++))
                ;;
        esac
    done

    # Mover archivo con verificación
    if mv -fv "$archivo" "$destino"; then
        echo "Movido exitosamente: $(printf "%q" "$archivo") -> $(printf "%q" "$destino")"
    else
        echo "Error al mover: $(printf "%q" "$archivo") (Código: $?)" >&2
    fi
done

# Eliminar directorios vacíos de forma segura
if [ "$eliminar_directorios_vacios" = true ]; then
    find . -mindepth 1 -type d -empty -delete 2>/dev/null
    echo "Directorios vacíos eliminados"
fi

echo "Operación completada en: $(pwd)"

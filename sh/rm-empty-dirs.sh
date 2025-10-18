#!/bin/bash

# Verificar que no se ejecute en la raíz del sistema
if [[ "$PWD" == "/" ]]; then
    echo "Error: Este script no puede ejecutarse en la raíz del sistema."
    exit 1
fi

# Obtener profundidad (por argumento o preguntar al usuario)
if [[ $# -eq 1 ]]; then
    depth="$1"
else
    read -p "Ingrese la profundidad máxima (>=1): " depth
fi

# Validar entrada de profundidad
if ! [[ "$depth" =~ ^[1-9][0-9]*$ ]]; then
    echo "Error: La profundidad debe ser un número entero positivo."
    exit 1
fi

# Encontrar y eliminar directorios vacíos con la profundidad especificada
echo "Buscando directorios vacíos hasta profundidad $depth..."
found=0
while IFS= read -r -d $'\0' dir; do
    echo "Encontrado directorio vacío: $dir"
    found=$((found + 1))
done < <(find . -mindepth 1 -maxdepth "$depth" -type d -empty -print0)

if [[ $found -eq 0 ]]; then
    echo "No se encontraron directorios vacíos en el rango especificado."
    exit 0
fi

# Confirmar eliminación
read -p "¿Eliminar $found directorio(s) vacío(s)? [s/N]: " respuesta
if [[ "${respuesta,,}" != "s" ]]; then
    echo "Operación cancelada."
    exit 0
fi

# Eliminar los directorios
find . -depth -mindepth 1 -maxdepth "$depth" -type d -empty -exec rmdir -v {} \;
echo "Operación completada."

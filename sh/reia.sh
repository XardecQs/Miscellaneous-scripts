#!/usr/bin/env bash

# Crear directorio para imágenes reescaladas
OUTPUT_DIR="imagenes_reescaladas"
mkdir -p "$OUTPUT_DIR"

# Procesar todas las imágenes en el directorio actual
for image in *.{jpg,jpeg,png,webp,JPG,JPEG,PNG,WEBP}; do
    if [ -f "$image" ]; then
        echo "Procesando: $image"
        
        # Extraer nombre del archivo sin extensión
        filename=$(basename -- "$image")
        filename_noext="${filename%.*}"
        
        # Reescalar la imagen y guardar en el subdirectorio
        realesrgan-ncnn-vulkan -i "$image" -o "$OUTPUT_DIR/${filename_noext}.png" -m /home/xardec/.dotfiles/IA/models -n 4xNomos8kSC
        
        if [ $? -eq 0 ]; then
            echo "✓ Completado: $image"
        else
            echo "✗ Error al procesar: $image"
        fi
        sleep 1m
    fi
done

echo "Proceso terminado. Las imágenes reescaladas están en: $OUTPUT_DIR/"

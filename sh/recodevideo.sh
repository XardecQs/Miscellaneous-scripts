#!/usr/bin/env bash

mkdir -p recode

for file in *.{mp4,avi,mkv,mov,flv,wmv,webm,3gp}; do
    if [ -f "$file" ]; then
        echo "Procesando: $file"
        ffmpeg -i "$file" "recode/$file"
    fi
done

echo "Procesamiento completado"

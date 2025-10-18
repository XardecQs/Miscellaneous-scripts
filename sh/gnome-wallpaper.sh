#!/usr/bin/env bash
# Cambia fondos de pantalla en GNOME

#---------------------------------------------#
IMAGE_DIR="$HOME/Media/Imágenes/Wallpapers"
#---------------------------------------------#

check_deps() {
  local missing=()
  for cmd in zenity gsettings; do
    if ! command -v "$cmd" &> /dev/null; then
      missing+=("$cmd")
    fi
  done
  
  if [ ${#missing[@]} -gt 0 ]; then
    zenity --error --text="Faltan dependencias requeridas:\n${missing[*]}"
    exit 1
  fi
}

select_image() {
  zenity --file-selection --title="Selecciona una imagen de fondo" \
    --file-filter="Imágenes | *.jpeg *.jpg *.png *.gif *.pnm *.tga *.tiff *.webp *.bmp *.farbfeld" \
    --filename="$IMAGE_DIR/" --width=900 --height=700
}

set_image_wallpaper() {
  gsettings set org.gnome.desktop.background picture-uri-dark "file://$IMAGE"
  gsettings set org.gnome.desktop.background picture-uri "file://$IMAGE"
}

select_random_img() {
  find "$IMAGE_DIR" -type f \( -iname "*.jpeg" -o -iname "*.jpg" -o -iname "*.png" \
      -o -iname "*.gif" -o -iname "*.pnm" -o -iname "*.tga" -o -iname "*.tiff" -o -iname "*.webp" \
      -o -iname "*.bmp" -o -iname "*.farbfeld" \) | shuf -n 1
}

#---------------------------------------------#
check_deps

case ${1:-$(zenity --list --title="Seleccionar fondo" --text="Elige una opción:" \
    --column="Opción" "Imagen aleatoria" "Imagen manual" \
    --height=300 --width=300)} in
  "Imagen manual")
    IMAGE=$(select_image)
    [ -z "$IMAGE" ] && exit 1
    set_image_wallpaper
    ;;
  "Imagen aleatoria")
    IMAGE=$(select_random_img)
    set_image_wallpaper
    ;;
esac

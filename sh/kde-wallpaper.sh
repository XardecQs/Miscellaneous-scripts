#!/bin/bash

#---------------------------------------------#
IMAGE_DIR="$HOME/Media/Imágenes/Wallpapers"
COLOR_MODE=lighten    # [darken|lighten]
CACHE_FILE="$HOME/.cache/current_wallpaper"
THEME_NAME="Breeze"   # Nombre de tu tema KDE (Breeze, Breeze Dark, etc)
#---------------------------------------------#

check_deps() {
  local missing=()
  for cmd in kdialog wal qdbus; do
    if ! command -v "$cmd" &> /dev/null; then
      missing+=("$cmd")
    fi
  done
  
  if [ ${#missing[@]} -gt 0 ]; then
    kdialog --title "Error" --error "Faltan dependencias requeridas:\n${missing[*]}"
    exit 1
  fi
}

select_image() {
  kdialog --title "Selecciona una imagen de fondo" \
          --getopenfilename "$IMAGE_DIR/" \
          "Imágenes (*.jpeg *.jpg *.png *.gif *.pnm *.tga *.tiff *.webp *.bmp)"
}

set_image_kde() {
  # Guardar en caché la imagen actual
  echo "$IMAGE" > "$CACHE_FILE"
  
  # Establecer wallpaper en todos los escritorios
  qdbus org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "
    var allDesktops = desktops();
    for (i=0; i<allDesktops.length; i++) {
        d = allDesktops[i];
        d.wallpaperPlugin = 'org.kde.image';
        d.currentConfigGroup = ['Wallpaper', 'org.kde.image', 'General'];
        d.writeConfig('Image', 'file://$IMAGE');
    }
  "
  # Generar esquema de colores
  wal -i "$IMAGE" --cols16 $COLOR_MODE -n -e 
}

select_random_img() {
  find "$IMAGE_DIR" -type f \( -iname "*.jpeg" -o -iname "*.jpg" -o -iname "*.png" \
      -o -iname "*.gif" -o -iname "*.pnm" -o -iname "*.tga" -o -iname "*.tiff" -o -iname "*.webp" \
      -o -iname "*.bmp" \) | shuf -n 1
}

recalcular_colores() {
  if [ -f "$CACHE_FILE" ]; then
    wal -i "$(cat "$CACHE_FILE")" --cols16 $COLOR_MODE -n -e
    kdialog --passivepopup "Colores recalculados" 2
  else
    kdialog --title "Error" --error "No hay imagen de fondo guardada en caché"
  fi
}

sddm() {
  local sddm_wall="/usr/share/sddm/themes/sugar-candy/Backgrounds/wallpaper.jpg"
  if [ -f "$CACHE_FILE" ]; then
    cp "$(cat "$CACHE_FILE")" "$sddm_wall" || true
    cp "$(cat "$CACHE_FILE")" "/usr/share/sddm/themes/Apple.Tahoe/wallpaper" || true
  fi

  if [ -f ~/.cache/wal/colors ]; then
    ACCENT_COLOR=$(sed -n '10p' ~/.cache/wal/colors || echo "#fb884f")
    local theme_conf="${sddm_wall%/Backgrounds*}/theme.conf"
    
    # Actualizar colores en tema SDDM
    sed -i "s/AccentColor=.*/AccentColor=$ACCENT_COLOR/" "$theme_conf"
    sed -i "s/Background=.*/Background=\"$sddm_wall\"/" "$theme_conf"
  fi
}

# Menú principal con kdialog
show_main_menu() {
  kdialog --title "Selector de Fondos" \
          --radiolist "Selecciona una opción:" \
          "1" "Imagen manual" on \
          "2" "Imagen aleatoria" off \
          "3" "Recalcular colores" off
}

#---------------------------------------------#
check_deps

# Mostrar menú si no se pasaron argumentos
if [ $# -eq 0 ]; then
  choice=$(show_main_menu)
else
  choice="$1"
fi

case "$choice" in
  "1")
    IMAGE=$(select_image)
    [ -z "$IMAGE" ] && exit 0
    set_image_kde
    ;;
  "2")
    IMAGE=$(select_random_img)
    set_image_kde
    ;;
  "3")
    recalcular_colores
    ;;
  *)
    exit 0
    ;;
esac

sddm

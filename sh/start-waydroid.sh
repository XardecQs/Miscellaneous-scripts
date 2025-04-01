#!/bin/bash

# --- CONFIGURACIÓN ---
MOUNT_POINTS=(
    "/home/xardec/Descargas:/home/xardec/.local/share/waydroid/data/media/0/Download"
    #"/home/xardec/Media/Mangas/Kotatsu:/home/xardec/.local/share/waydroid/data/media/0/Android/data/org.koitharu.kotatsu/files/manga"
)

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# --- FUNCIONES ---
check_mount() {
  if sudo mountpoint "$target" | grep -q no; then
    #no montado
    echo "🔗⬆️ Montando $source → $target..."
    sudo mount --bind "$source" "$target" && echo -e "${GREEN}✓ Montaje exitoso!${NC}"
  else
    #montado
    echo "✅ Ya está montado: $source → $target"
  fi
}

start_waydroid() {
    if waydroid status | grep -q "RUNNING"; then
        #running
        echo "🚀 Waydroid ya está en ejecución. Mostrando interfaz..."
        waydroid show-full-ui
    else
        #stopped
        echo "🚩 Iniciando Waydroid"
        waydroid session start & disown
        sleep 5
        waydroid show-full-ui
    fi
}

remount(){
  echo "----------------------------------------"
  umount-targets "$target"
  check_mount
}

umount-targets() {
  if sudo mountpoint "$target" | grep -q no; then
    #no montado
    echo "✅ Ya esta desmontado: $target"
  else
    #montado
    echo "✅ Desmontando: $target"
    sudo umount "$target"
  fi
}

restart_waydroid() {
    echo "🔄 Reiniciando Waydroid..."
    waydroid session stop
    start_waydroid
}

show_help() {
    echo "Uso: $0 [OPCIÓN]"
    echo "Opciones:"
    echo "  -r    Remontar todos los puntos"
    echo "  -m    Montar todos los puntos (default)"
    echo "  -u    Desmontar todos los puntos"
    echo "  -w    Reiniciar Waydroid"
    echo "  -h    Mostrar ayuda"
    echo "  -off  Apaga waydroid"
    echo ""
    echo "Ejemplos:"
    echo "  $0       # Montar y ejecutar (default)"
    echo "  $0 -u    # Desmontar todos"
}

shutdown-waydroid() { 
    if waydroid status | grep -q "RUNNING"; then
        #running
        waydroid session stop
        echo "❌⏳ Apagando Waydroid"
    else
        #stopped
        echo "Waydroid ya esta apagado"
    fi

}
# --- EJECUCIÓN ---
# montajes
for point in "${MOUNT_POINTS[@]}"; do
  IFS=':' read -r source target <<< "$point"
  case "$1" in
    -r)
      remount
      ;;
    -u)
      umount-targets
      ;;
    -m)
      check_mount
      ;;
    -off)
      umount-targets
      ;;
    "")
      check_mount
      ;;
  esac
done

case "$1" in
  -h|--help)
    show_help
    ;;
  -w)
    restart_waydroid
    ;;
  -off)
    shutdown-waydroid
    ;;
  "")
    start_waydroid
    ;;
esac

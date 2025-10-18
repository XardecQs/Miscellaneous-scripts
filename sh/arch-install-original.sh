#!/usr/bin/env bash
set -euo pipefail

# Colores para mensajes
RED='\e[1;31m'
GREEN='\e[1;32m'
YELLOW='\e[1;33m'
BLUE='\e[1;34m'
NC='\e[0m' # No Color

# --------------------------------------------
# CONFIGURACIÓN
# --------------------------------------------
HOSTNAME="arch-pc"
TIMEZONE="America/Lima"
KEYMAP="la-latin1"
LANG="es_PE.UTF-8"
EFI_SIZE="513"   # Tamaño EFI en MiB (mínimo 300, recomendado 512+)
BOOT_SIZE="1024" # Tamaño /boot en MiB (recomendado 1GB)
PACKAGES="base base-devel linux linux-firmware networkmanager grub wpa_supplicant efibootmgr zsh nvim git openssh os-prober"

# --------------------------------------------
# INICIO DEL SCRIPT
# --------------------------------------------
clear
echo -e "${YELLOW}"
echo "==================================================="
echo "          INSTALADOR DE ARCH LINUX CON UEFI"
echo "==================================================="
echo -e "${NC}"

# Mostrar discos disponibles
echo -e "${GREEN}Discos disponibles:${NC}"
lsblk -d -e 7,11 -o NAME,SIZE,TYPE | grep "disk"
echo ""
echo -e "${YELLOW}Ingresa el nombre del disco (ej: sda, vda):${NC}"
read -rp "Disco: " DISK
DISK="/dev/$DISK"

# Enfatizar advertencia de borrado
echo -e "\n${RED}¡ADVERTENCIA!${NC}"
echo -e "${YELLOW}Esta operación borrará TODOS los datos en ${DISK}${NC}"
echo -e "${YELLOW}No podrás recuperar ningún archivo después de continuar${NC}\n"

if ! read -rp "¿Estás completamente seguro de continuar? (escribe 'SI' en mayúsculas): " CONFIRM
then
    echo -e "${RED}Instalación cancelada.${NC}"
    exit 1
fi

if [[ "$CONFIRM" != "SI" ]]; then
    echo -e "${RED}No se confirmó la operación. Instalación cancelada.${NC}"
    exit 1
fi

# Verificar UEFI
if [[ ! -d /sys/firmware/efi ]]; then
    echo -e "${RED}ERROR: Este sistema no tiene UEFI habilitado"
    echo "El script solo funciona con sistemas UEFI"
    exit 1
fi

# Configurar hora con verificación
echo -e "${GREEN}\nConfigurando hora automática...${NC}"
timedatectl set-ntp true
echo -e "${BLUE}Verificando sincronización del reloj:${NC}"
if timedatectl | grep -q "System clock synchronized: yes"; then
    echo -e "${GREEN}Reloj del sistema sincronizado correctamente${NC}"
else
    echo -e "${YELLOW}Advertencia: El reloj del sistema no está sincronizado${NC}"
fi

# --------------------------------------------
# PARTICIONADO Y FORMATEO
# --------------------------------------------
echo -e "${GREEN}\nCreando particiones en $DISK...${NC}"

# Calcular tamaños
TOTAL_SIZE=$(parted -s "$DISK" unit MiB print | grep "Disk /" | awk '{print $3}' | tr -d 'MiB')
SWAP_SIZE=$(free -m | awk '/Mem:/ {print $2}') # Tamaño swap = RAM en MiB
ROOT_END=$((TOTAL_SIZE - SWAP_SIZE))

# Crear particiones
parted -s "$DISK" mklabel gpt
parted -s "$DISK" mkpart "EFI" fat32 1MiB "${EFI_SIZE}MiB"
parted -s "$DISK" set 1 esp on
parted -s "$DISK" mkpart "BOOT" ext4 "${EFI_SIZE}MiB" "$((EFI_SIZE + BOOT_SIZE))MiB"
parted -s "$DISK" mkpart "ROOT" btrfs "$((EFI_SIZE + BOOT_SIZE))MiB" "${ROOT_END}MiB"
parted -s "$DISK" mkpart "SWAP" linux-swap "${ROOT_END}MiB" 100%

# Formatear particiones
echo -e "${GREEN}Formateando particiones...${NC}"
mkfs.fat -F32 "${DISK}1"
mkfs.ext4 -F "${DISK}2"
mkfs.btrfs -f "${DISK}3"
mkswap "${DISK}4"
swapon "${DISK}4"

# Configurar subvolúmenes Btrfs
echo -e "${GREEN}Configurando subvolúmenes Btrfs...${NC}"
mount "${DISK}3" /mnt
cd /mnt
btrfs subvolume create @
btrfs subvolume create @home
btrfs subvolume create @tmp
cd /
umount /mnt

# Montar subvolúmenes
mount -o rw,subvol=@,space_cache=v2 "${DISK}3" /mnt
mkdir -p /mnt/{boot,home,tmp}
mount "${DISK}2" /mnt/boot
mkdir -p /mnt/boot/efi
mount "${DISK}1" /mnt/boot/efi
mount -o rw,subvol=@home,space_cache=v2 "${DISK}3" /mnt/home
mount -o rw,subvol=@tmp,space_cache=v2 "${DISK}3" /mnt/tmp

# --------------------------------------------
# INSTALAR SISTEMA BASE
# --------------------------------------------
echo -e "${GREEN}\nInstalando sistema base...${NC}"
pacstrap /mnt $PACKAGES
genfstab -U /mnt > /mnt/etc/fstab

# Añadir opciones de seguridad a /tmp
echo -e "${GREEN}Aplicando opciones de seguridad a /tmp...${NC}"
sed -i '/subvol=@tmp/s/defaults/defaults,noexec,nosuid,nodev/' /mnt/etc/fstab

# --------------------------------------------
# CREAR SCRIPT DE CONFIGURACIÓN (chroot)
# --------------------------------------------
echo -e "${GREEN}\nPreparando configuración post-instalación...${NC}"
cat << 'EOF' > /mnt/arch-chroot.sh
#!/bin/bash
set -euo pipefail

# Colores para mensajes
RED='\e[1;31m'
GREEN='\e[1;32m'
YELLOW='\e[1;33m'
BLUE='\e[1;34m'
NC='\e[0m' # No Color

# --------------------------------------------
# CONFIGURACIÓN BÁSICA DEL SISTEMA
# --------------------------------------------
echo -e "${GREEN}Configurando sistema base...${NC}"

# Obtener variables del script principal
HOSTNAME="arch-pc"
TIMEZONE="America/Lima"
KEYMAP="la-latin1"
LANG="es_PE.UTF-8"

# Configurar hostname
echo "$HOSTNAME" > /etc/hostname
echo -e "${BLUE}Hostname configurado como: $HOSTNAME${NC}"

# Configurar zona horaria
ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
hwclock --systohc
echo -e "${BLUE}Zona horaria configurada como: $TIMEZONE${NC}"

# Configurar locale
sed -i "s/#$LANG/$LANG/" /etc/locale.gen
locale-gen

# Configurar todas las variables LC
cat > /etc/locale.conf << LOCALE_CONF
LANG=$LANG
LC_ADDRESS=$LANG
LC_IDENTIFICATION=$LANG
LC_MEASUREMENT=$LANG
LC_MONETARY=$LANG
LC_NAME=$LANG
LC_NUMERIC=$LANG
LC_PAPER=$LANG
LC_TELEPHONE=$LANG
LC_TIME=$LANG
LOCALE_CONF
echo -e "${BLUE}Idioma configurado como: $LANG${NC}"

# Configurar teclado
echo "KEYMAP=$KEYMAP" > /etc/vconsole.conf
echo -e "${BLUE}Mapa de teclado configurado como: $KEYMAP${NC}"

# Configurar hosts
cat > /etc/hosts << HOSTS_EOF
127.0.0.1    localhost
::1          localhost
127.0.0.1    $HOSTNAME.localdomain $HOSTNAME
HOSTS_EOF
echo -e "${BLUE}Archivo /etc/hosts configurado${NC}"

# --------------------------------------------
# CONFIGURACIÓN DE USUARIOS
# --------------------------------------------
echo -e "${GREEN}\nConfigurando usuarios...${NC}"

# Configurar usuario root
echo ""
echo -e "${YELLOW}CONFIGURANDO USUARIO ROOT${NC}"
echo "Ingresa la nueva contraseña para root:"
passwd

# Crear usuario principal
echo ""
echo -e "${YELLOW}CREANDO USUARIO PRINCIPAL${NC}"
read -rp "Nombre de usuario: " USERNAME
useradd -m -G wheel -s /bin/zsh "$USERNAME"
echo "Ingresa la contraseña para $USERNAME:"
passwd "$USERNAME"

# Configurar sudo
echo '%wheel ALL=(ALL:ALL) ALL' > /etc/sudoers.d/wheel
echo -e "${BLUE}Permisos sudo configurados para el grupo wheel${NC}"

# --------------------------------------------
# INSTALACIÓN DE GRUB
# --------------------------------------------
echo -e "${GREEN}\nInstalando gestor de arranque...${NC}"
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id="ArchLinux"

# Configurar GRUB
sed -i 's/^GRUB_DEFAULT=.*/GRUB_DEFAULT=saved/' /etc/default/grub
sed -i 's/#GRUB_SAVEDEFAULT/GRUB_SAVEDEFAULT/' /etc/default/grub
echo 'GRUB_DISABLE_OS_PROBER=false' >> /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg
echo -e "${BLUE}GRUB instalado y configurado correctamente${NC}"

# --------------------------------------------
# CONFIGURACIÓN DE SERVICIOS
# --------------------------------------------
echo -e "${GREEN}\nHabilitando servicios...${NC}"
systemctl enable NetworkManager
systemctl enable wpa_supplicant
echo -e "${BLUE}Servicios de red habilitados${NC}"

# --------------------------------------------
# CONFIGURACIÓN DE REPOSITORIOS ADICIONALES
# --------------------------------------------
echo -e "${GREEN}\nConfigurando Chaotic-AUR...${NC}"
pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
pacman-key --lsign-key 3056513887B78AEB
pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst'
pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'
echo -e "\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist" >> /etc/pacman.conf
pacman -Sy --noconfirm yay
echo -e "${BLUE}Chaotic-AUR y yay configurados correctamente${NC}"

# --------------------------------------------
# INSTALACIÓN DE ENTORNO GRÁFICO
# --------------------------------------------
echo ""
read -rp "¿Instalar entorno gráfico? (s/N): " gui
if [[ "$gui" =~ ^[Ss]$ ]]; then
    echo "1) GNOME  2) KDE  3) XFCE"
    read -rp "Opción: " desktop
    
    case $desktop in
        1) 
            echo -e "${GREEN}Instalando GNOME...${NC}"
            pacman -S --noconfirm gnome gdm
            systemctl enable gdm
            echo -e "${BLUE}GNOME instalado correctamente${NC}"
            ;;
        2) 
            echo -e "${GREEN}Instalando KDE Plasma...${NC}"
            pacman -S --noconfirm plasma sddm
            systemctl enable sddm
            echo -e "${BLUE}KDE Plasma instalado correctamente${NC}"
            ;;
        3) 
            echo -e "${GREEN}Instalando XFCE...${NC}"
            pacman -S --noconfirm xfce4 lightdm lightdm-gtk-greeter
            systemctl enable lightdm
            echo -e "${BLUE}XFCE instalado correctamente${NC}"
            ;;
    esac
fi

# --------------------------------------------
# MENSAJE DE BIENVENIDA
# --------------------------------------------
cat > /etc/issue << WELCOME_EOF

Bienvenido a tu sistema Arch Linux!

WELCOME_EOF

# --------------------------------------------
# FINALIZACIÓN
# --------------------------------------------
echo -e "${GREEN}\nConfiguración completada!${NC}"
rm /arch-chroot.sh
EOF

# Dar permisos y ejecutar
chmod +x /mnt/arch-chroot.sh
echo -e "${GREEN}\nIngresando en chroot para configuración final...${NC}"
arch-chroot /mnt /arch-chroot.sh

# --------------------------------------------
# FINALIZAR
# --------------------------------------------
echo -e "${GREEN}\nDesmontando particiones...${NC}"
umount -R /mnt
swapoff -a

echo -e "${GREEN}\n¡Instalación completada con éxito!${NC}"
echo -e "${YELLOW}El sistema se reiniciará en 10 segundos...${NC}"
echo -e "Puedes cancelar con Ctrl+C"
sleep 10
shutdown -r now

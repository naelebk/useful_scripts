#!/bin/bash

#################################################################################
# ========================= COPYRIGHT : © Naël EMBARKI © ======================== 
#################################################################################
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
PURPLE='\033[0;35m'
RED='\033[0;31m'
NC='\033[0m'
TYPE_ISO="ISO 9660"

super_echo() {
    local first_color="$1"
    local message="$2"
    local end="$3"
    eval "color=\${$first_color}"
    if [ -z "$color" ]; then
        echo -e "${RED}Couleur non supportée : ${ORANGE}$first_color${NC}"
        return 1
    fi
    echo -ne "${color}${message}${NC}"
    [ "$end" != "n" ] && echo "" || echo -n ""
}

check_cmd() {
    if [ $? -eq 0 ]; then
        super_echo "GREEN" "OK" n
        [ $# -ne 1 ] && super_echo "GREEN" "." || super_echo "GREEN" " pour $1."
    else
        super_echo "RED" "ERREUR " n
        [ $# -ne 1 ] && super_echo "RED" "!" || super_echo "RED" "pour $1 !"
        exit 1
    fi
}

# Alias : What We Want
WWW=""
action() {
    echo -ne "${YELLOW}$1${NC} "
    read WWW
    echo -ne "${PURPLE}Êtes vous sûr ? (Oui/Non)${NC} "
    read yon
    while [[ "$(echo "$yon" | tr '[:upper:]' '[:lower:]')" != "oui" ]]; do
        echo -ne "${YELLOW}$1${NC} "
        read WWW
        echo -ne "${PURPLE}Êtes vous sûr ? (Oui/Non)${NC} "
        read yon
    done
}

choice() {
    action "$1"
    eval "$2=$WWW"
}

choice_string() {
    action "$1"
    eval "$2=\"$WWW\""
}

is_file_type() {
    if file_command_output=$(file "$1" | grep "$2"); then
        return 0
    fi
    return 1
}

download_tuto() {
    local my_file=$1
    local repository=$2
    super_echo YELLOW "Archive..... " n
    wget "https://github.com/naelebk/useful_scripts/archive/refs/heads/$my_file" > /dev/null 2>&1
    check_cmd
    super_echo YELLOW "Dézippage..... " n
    unzip "$my_file" > /dev/null 2>&1
    check_cmd
    super_echo YELLOW "Permissions..... " n
    chmod -R 755 *
    check_cmd
    super_echo YELLOW "Suppresion du zip..... " n
    rm "$my_file" > /dev/null 2>&1
    check_cmd
    super_echo YELLOW "Déplacement du tuto dans l'espace courant..... " n
    mv useful_scripts-main/$repository . > /dev/null 2>&1
    check_cmd
    super_echo YELLOW "Suppression des répertoire inutiles..... " n
    rm -r useful_scripts-main > /dev/null 2>&1
    check_cmd
    super_echo YELLOW "Accès au répertoire $repository..... " n
    cd $repository > /dev/null 2>&1
    check_cmd 
}

make_tuto() {
    ./sbin/woeusb --device "$1" "$2"
}

install_package() {
    PACKAGES_NAME=$@
    for PACKAGE_NAME in $PACKAGES_NAME; do
        super_echo YELLOW "Installation de $PACKAGE_NAME..... " n
        if [ -f /etc/debian_version ]; then
            sudo apt-get update > /dev/null 2>&1
            sudo apt-get install -y "$PACKAGE_NAME" > /dev/null 2>&1
        elif [ -f /etc/redhat-release ]; then
            if command -v dnf >/dev/null 2>&1; then
                sudo dnf install -y "$PACKAGE_NAME" > /dev/null 2>&1 
            else
                sudo yum install -y "$PACKAGE_NAME" > /dev/null 2>&1
            fi
        elif [ -f /etc/arch-release ]; then
            sudo pacman -Sy --noconfirm "$PACKAGE_NAME" > /dev/null 2>&1
        elif [ -f /etc/SuSE-release ]; then
            sudo zypper install -y "$PACKAGE_NAME" > /dev/null 2>&1
        else
            return 1
        fi
        check_cmd "$PACKAGE_NAME"
    done
    return 0
}

get_wimtools_package_name() {
    if [ -f /etc/redhat-release ] || [ -f /etc/arch-release ] || [ -f /etc/SuSE-release ]; then
        echo "wimlib"
    else
        echo "wimtools"
    fi
}

install_bios_package() {
    if [ -f /etc/debian_version ]; then
        install_package "grub-pc-bin" "grub-efi-amd64-bin"
    elif [ -f /etc/redhat-release ]; then
        install_package "grub2-pc" "grub2-efi-x64"
    elif [ -f /etc/arch-release ]; then
        install_package "grub"
    elif [ -f /etc/SuSE-release ]; then
        install_package "grub2-i386-pc" "grub2-x86_64-efi"
    else
        super_echo RED "Distribution non suportée. Terminaison."
        exit 10
    fi
}

get_partitions() {
    local disk="$1"
    local partitions=""
    if [ -z "$disk" ]; then
        super_echo "RED" "Aucun disque spécifié ! Terminaison."
        exit 15
    fi
    partitions=$(lsblk -lnpo NAME,TYPE,MOUNTPOINTS "$disk" 2>/dev/null | awk '
        $2 == "part" && $3 !~ /(SWAP|\/boot\/u?efi|\/)/ {print $1}'
    )
    if [ -z "$partitions" ]; then
        super_echo "RED" "Aucune partition valide détectée sur '$disk' ! Terminaison."
        exit 15
    fi
    local valid_partitions=""
    for part in $partitions; do
        if udevadm info --query=property --name=$(lsblk -no pkname "$part") | grep -q ID_BUS=usb; then
            valid_partitions="$valid_partitions $part"
        fi
    done
    valid_partitions=$(echo "$valid_partitions" | sed -E 's/^\s+|\s+$//g')
    if [ -z "$valid_partitions" ]; then
        super_echo "RED" "Aucune partition valide détectée après vérification sur '$disk' ! Terminaison."
        exit 15
    fi
    echo "$valid_partitions"
}

umount_usb() {
    USB_DEVICE=$1
    if [ -z "$USB_DEVICE" ]; then
        super_echo RED "Aucun périphérique USB spécifié."
        return 1
    fi
    if [ ! -b "$USB_DEVICE" ]; then
        super_echo RED "Le périphérique $USB_DEVICE n'existe pas."
        return 1
    fi
    # Inversement de l'ordre du démontage (car erreur sur système de fichier sinon...)
    PARTITIONS=$(get_partitions "$USB_DEVICE" | tr ' ' '\n' | tac | tr '\n' ' ')
    for PARTITION in $PARTITIONS; do
        if grep -qE "$PARTITION" /proc/mounts; then
            super_echo YELLOW "Démontage de $PARTITION..... " n
            sudo umount "$PARTITION" > /dev/null 2>&1
            check_cmd
        fi
    done
    return 0
}

mount_usb() {
    USB_DEVICE=$1
    PARTITIONS=$(get_partitions "$USB_DEVICE")
    for PARTITION in $PARTITIONS; do
        super_echo YELLOW "Montage de $PARTITION..... " n
        if ! grep -qE "$PARTITION" /proc/mounts; then
            sudo mount "$PARTITION" /media/ > /dev/null 2>&1
        fi
        check_cmd "$PARTITION"
    done
}

detect_usb_device() {
    USB_DEVICES=$(lsblk -lnpo NAME,TRAN | grep "usb" | awk '{print $1}')
    DEVICE_COUNT=$(echo "$USB_DEVICES" | wc -l)
    [[ "$DEVICE_COUNT" -eq 1 && ! -z "$USB_DEVICES" ]] && echo "$USB_DEVICES" || echo "KO"
}

if [[ "$(id -u)" != "0" ]]; then
	super_echo RED "Le script doit être exécuté en tant que superutilisateur (root)."
	exit 1
fi
if [[ $(ls *.iso 2>/dev/null | wc -l) -ne 1 ]] && [[ "$#" -ne 1 ]]; then
    super_echo RED "Le répertoire courant ($(pwd)) ne contient aucune image iso ! Il doit en contenir exactement une ou bien passer le fichier comme premier argument de la ligne de commande."
    super_echo YELLOW "Synopsis :\n$0 (avec une image iso dans le répertoire courant).\nOu bien :\n$0 ISO_FILE"
	exit 2
fi
if [[ -d "naelebk_tuto_woeusb" ]]; then
	super_echo YELLOW "Suppression du répertoire naelebk_tuto_woeusb..... " n
	rm -rf naelebk_tuto_woeusb
	check_cmd
fi
if [[ -d "useful_scripts-main" ]]; then
    super_echo YELLOW "Suppression du répertoire useful_scripts-main..... " n
    rm -rf useful_scripts-main
    check_cmd
fi
iso_file=""
if [[ -n "$1" ]] && [[ "$#" -eq 1 ]]; then
    iso_file="$1"
else
    iso_file="$PWD/$(basename $(ls -1 *.iso 2>/dev/null | head -n 1))"
fi
super_echo YELLOW "Vérification de l'image iso ($iso_file)..... " n
if [[ -f "$iso_file" ]]; then
    if is_file_type "$iso_file" "$TYPE_ISO"; then
        super_echo GREEN "OK. Fichier ISO valide."
    else
        super_echo RED "KO ! Fichier ISO invalide."
        exit 3
    fi
else
    super_echo RED "KO ! $iso_file n'est pas un fichier."
    exit 4
fi

super_echo YELLOW "Détection de la clé usb..... " n
cle=$(detect_usb_device)
if [ $cle = "KO" ]; then
    super_echo RED "KO ! Aucune clé usb valide détectée ou plusieurs médias amovibles connectés (merci d'en connecter qu'un seul à votre ordinateur). Terminaison."
    exit 5
fi
check_cmd "$cle"

if ! grep -qs "$cle" /proc/mounts; then
    super_echo PURPLE "Montage de $cle"
    mount_usb "$cle"
fi

super_echo PURPLE "Démontage de $cle"
umount_usb "$cle"

install_package "$(get_wimtools_package_name)"
install_bios_package

super_echo "PURPLE" "Téléchargement du tutoriel"
download_tuto "main.zip" "naelebk_tuto_woeusb"

super_echo PURPLE "Processus de la création de la clé usb lancé, cela peut prendre du temps, merci de patienter"
make_tuto "$iso_file" "$cle"
check_cmd

super_echo YELLOW "Terminaison du script, éjection de $cle..... " n
sudo eject "$cle" > /dev/null 2>&1
check_cmd

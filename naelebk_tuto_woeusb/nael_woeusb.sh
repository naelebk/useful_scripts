#!/bin/bash

#################################################################################
# ========================= COPYRIGHT : © Naël EMBARKI © ======================== 
#################################################################################
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
PURPLE='\033[0;35m'
RED='\033[0;31m'
NC='\033[0m'

check_cmd() {
    if [[ $? -eq 0 ]]; then
        if [ -z "$1" ]; then 
            echo -e "${GREEN}OK.${NC}"
        else 
            echo -e "${GREEN}OK pour $1.${NC}"
        fi
    else
        if [[ -z "$1" ]]; then 
            echo -e "${RED}ERREUR !${NC}"
            exit 42
        else
            echo -e "${RED}ERREUR pour $1.${NC}"
            exit 42
        fi
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

super_echo() {
    local first_color=$1
    local message=$2
    local end=$3
    case "$first_color" in
        RED)
            echo -ne "${RED}${message}${NC}"
            ;;
        PURPLE)
            echo -ne "${PURPLE}${message}${NC}"
            ;;
        YELLOW)
            echo -ne "${YELLOW}${message}${NC}"
            ;;
        GREEN)
            echo -ne "${GREEN}${message}${NC}"
            ;;
        WHITE)
            echo -n "${message}"
            ;;
        *)
            echo "Couleur non supportée : $first_color"
            return 1
            ;;
    esac
    if [[ "$end" == "n" ]]; then
        echo -n ""
    else
        echo ""
    fi
}

is_iso_file() {
    if file_command_output=$(file "$1" | grep "ISO 9660"); then
        return 0
    fi
    return 1
}

download_tuto() {
    local my_file=$1
    local repository=$2
    super_echo YELLOW "Archive..... " n
    wget "https://github.com/naelebk/useful_scripts/archive/refs/heads/$my_file" > /dev/null 2>&1
    check_cmd ""
    super_echo YELLOW "Dézippage..... " n
    unzip "$my_file" > /dev/null 2>&1
    check_cmd ""
    super_echo YELLOW "Permissions..... " n
    chmod -R 755 *
    check_cmd ""
    super_echo YELLOW "Suppresion du zip..... " n
    rm "$my_file" > /dev/null 2>&1
    check_cmd ""
    super_echo YELLOW "Déplacement du tuto dans l'espace courant..... " n
    mv useful_scripts-main/$repository . > /dev/null 2>&1
    check_cmd ""
    super_echo YELLOW "Suppression des répertoire inutiles..... " n
    rm -r useful_scripts-main > /dev/null 2>&1
    check_cmd ""
    super_echo YELLOW "Accès au répertoire $repository..... " n
    cd $repository > /dev/null 2>&1
    check_cmd "" 
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
    PARTITIONS=$(lsblk -lnpo NAME "$1" | grep -v "^$1$")
    if [ -z "$PARTITIONS" ]; then
        super_echo RED "Aucune partition trouvée sur $1."
        exit 15
    fi
    echo "$PARTITIONS"
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
    PARTITIONS=$(get_partitions "$USB_DEVICE")
    for PARTITION in $PARTITIONS; do
        super_echo YELLOW "Démontage de $PARTITION..... " n
        grep -q "$PARTITION" /proc/mounts && sudo umount "$PARTITION" > /dev/null 2>&1
        check_cmd ""
    done
    return 0
}

mount_usb() {
    USB_DEVICE=$1
    PARTITIONS=$(get_partitions "$USB_DEVICE")
    for PARTITION in $PARTITIONS; do
        super_echo YELLOW "Montage de $PARTITION..... " n
        if ! grep -q "$PARTITION" /proc/mounts; then
            sudo mount "$PARTITION" /media/ > /dev/null 2>&1
            check_cmd ""
        else
            super_echo GREEN "OK. Partition $PARTITION déjà montée."
        fi
    done
}

detect_usb_device() {
    USB_DEVICES=$(lsblk -lnpo NAME,TRAN | grep "usb" | awk '{print $1}')
    DEVICE_COUNT=$(echo "$USB_DEVICES" | wc -l)
    if [[ "$DEVICE_COUNT" -eq 1 && ! -z "$USB_DEVICES" ]]; then
        echo "$USB_DEVICES"
    else
        echo "KO"
    fi 
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
	check_cmd ""
fi
if [[ -d "useful_scripts-main" ]]; then
    super_echo YELLOW "Suppression du répertoire useful_scripts-main..... " n
    rm -rf useful_scripts-main
    check_cmd ""
fi
iso_file=""
if [[ -n "$1" ]] && [[ "$#" -eq 1 ]]; then
    iso_file="$1"
else
    iso_file="$PWD/$(basename $(ls -1 *.iso 2>/dev/null | head -n 1))"
fi
super_echo YELLOW "Vérification de l'image iso ($iso_file)..... " n
if [[ -f "$iso_file" ]]; then
    if is_iso_file "$iso_file"; then
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
    mount_usb "$cle"
fi

umount_usb "$cle"

install_package "$(get_wimtools_package_name)"
install_bios_package

super_echo "PURPLE" "Téléchargement du tutoriel..... "
download_tuto "main.zip" "naelebk_tuto_woeusb"

super_echo PURPLE "Processus de la création de la clé usb lancé, cela peut prendre du temps, merci de patienter..... "
make_tuto "$iso_file" "$cle"
check_cmd ""

super_echo YELLOW "Terminaison du script, éjection de $cle..... " n
sudo eject "$cle" > /dev/null 2>&1
check_cmd ""

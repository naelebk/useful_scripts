#!/bin/bash

#################################################################################
# ========================= COPYRIGHT : © Naël EMBARKI © ======================== 
#################################################################################
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
PURPLE='\033[0;35m'
RED='\033[0;31m'
NC='\033[0m'
OUT="VENTOY.tar.gz"
TYPE_ISO="ISO 9660"
# La version est automatiquement mis à jour en fonction des nouvelles versions de ventoy
# Comment est-elle mise à jour : script shell cherchant automatiquement la version, et 
# modifie le présent script avec la nouvelle version
VERSION="1.1.07"
REP="ventoy-$VERSION"
ISO="*.iso"
PILOTS="PILOTS.zip"
check_cmd() {
    if [[ $? -eq 0 ]] || [[ $? -eq 1 ]]; then
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

is_file_type() {
    if file_command_output=$(file "$1" | grep "$2"); then
        return 0
    fi
    return 1
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
    PARTITIONS=$(lsblk -lnpo NAME "$1" | grep -v "^$1$ | grep '[0-9]'")
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
    # Inversement de l'ordre du démontage (car erreur sur système de fichier sinon...)
    PARTITIONS=$(get_partitions "$USB_DEVICE" | tr ' ' '\n' | tac | tr '\n' ' ')
    for PARTITION in $PARTITIONS; do
        super_echo YELLOW "Démontage de $PARTITION..... " n
        grep -q "$PARTITION" /proc/mounts && sudo umount "$PARTITION" > /dev/null 2>&1
        check_cmd ""
    done
    return 0
}

mount_usb() {
    USB_DEVICE=$1
    TARGET=$2
    PARTITIONS=$(get_partitions "$USB_DEVICE")
    for PARTITION in $PARTITIONS; do
        super_echo YELLOW "Montage de $PARTITION..... " n
        if ! grep -q "$PARTITION" /proc/mounts; then
            sudo mount "$PARTITION" "$TARGET" > /dev/null 2>&1
            check_cmd ""
        else
            super_echo GREEN "OK. Partition $PARTITION déjà montée."
        fi
    done
}

detect_usb_device() {
    USB_DEVICES=$(lsblk -lnpo NAME,TRAN | grep "usb" | awk '{print $1}')
    DEVICE_COUNT=$(echo "$USB_DEVICES" | wc -l)
    [[ "$DEVICE_COUNT" -eq 1 && ! -z "$USB_DEVICES" ]] && echo "$USB_DEVICES" || echo "KO"
}

if [[ "$(id -u)" != "0" ]]; then
	echo -e "${RED}Le script doit être exécuter en tant que superutilisateur (root).${NC}" 
	exit 4
fi

if [[ -z $(file $ISO | grep -E "ISO") || "$(ls $ISO | wc -l)" -eq 0 ]]; then
    echo -e "${RED}Erreur, au moins une image ISO doit être présente dans CE répertoire pour exécuter le script !${NC}"
    exit 5
fi

for file in $ISO; do
    super_echo YELLOW "Vérification du fichier $file..... " n
    if is_file_type "$file" "$TYPE_ISO"; then
        super_echo GREEN "OK. Fichier ISO $file valide."
    else
        super_echo RED "KO ! Fichier ISO $file invalide."
        exit 33
    fi
done

if ! command -v curl >/dev/null 2>&1; then
	echo -ne "${YELLOW}Curl n'est pas installé. Installation..... ${NC}"
    install_package "curl"
    check_cmd "installation de curl"
    if [[ -z $(which blkid) ]]; then
        super_echo YELLOW "Installation de util-linux (pour ventoy)..... " n
        install_package "util-linux"
        check_cmd "util-linux"
    fi
fi

while [[ -f $OUT ]]; do
    echo -ne "${YELLOW}Suppression de $OUT car déjà existant..... ${NC}"
    rm -rf $OUT
    check_cmd ""
done
while [[ -d $REP ]]; do
    echo -ne "${YELLOW}Suppression de $REP car déjà existant..... ${NC}"
    rm -rf $REP
    check_cmd ""
done
echo -e "${YELLOW}Récupération des scripts pour installation (out : $OUT)..... ${NC}"
curl -LJ -o $OUT "https://github.com/ventoy/Ventoy/releases/download/v$VERSION/ventoy-$VERSION-linux.tar.gz"
check_cmd ""
echo -ne "${YELLOW}Permissions sur le zip..... ${NC}"
chmod -R 755 $OUT > /dev/null 2>&1
check_cmd ""
echo -ne "${YELLOW}Dézippage des scripts..... ${NC}"
tar -zxvf $OUT > /dev/null 2>&1
check_cmd ""
echo -ne "${YELLOW}Permissions du répertoire $REP..... ${NC}"
chmod -R 777 $REP
check_cmd ""
echo -ne "${YELLOW}Accès au répertoire $REP..... ${NC}"
cd $REP
check_cmd ""
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

echo -ne "${YELLOW}Lancement du script de ventoy..... ${NC}"
sudo sh ./Ventoy2Disk.sh -I "$cle"
check_cmd ""

MEDIA_AMOVIBLE="/media/ventoy_usb_dir"
if [ ! -d "$MEDIA_AMOVIBLE" ]; then
    super_echo YELLOW "Création du répertoire $MEDIA_AMOVIBLE..... " n
    mkdir "$MEDIA_AMOVIBLE"
    check_cmd ""
fi

super_echo YELLOW "Détection de la partition la plus grande..... " n
largest=$(lsblk -bn -o NAME,SIZE "$cle" | tail -n +2 | sort -k 2 | head -n 1 | awk '{print $1}' | sed -E 's/[├─└─]+/\/dev\//g')
check_cmd "$largest"

super_echo YELLOW "Montage de $largest dans $MEDIA_AMOVIBLE..... " n
sudo mount "$largest" "$MEDIA_AMOVIBLE"
check_cmd ""

echo -ne "${YELLOW}Retour au répertoire de départ..... ${NC}"
cd - > /dev/null 2>&1
check_cmd ""

for file in $ISO; do
    echo -ne "${YELLOW}Copie de $(basename $file) dans $MEDIA_AMOVIBLE..... ${NC}" 
    cp $file $MEDIA_AMOVIBLE
    check_cmd "$(basename $file)"
done

echo -ne "${YELLOW}Récupération des pilotes RST Floppy pour détection des disques (préventif)..... ${NC}"
curl -o "$PILOTS" "https://raw.githubusercontent.com/naelebk/useful_scripts/main/PILOTS.zip"
check_cmd ""
super_echo YELLOW "Permissions sur les pilotes ($PILOTS)..... " n
chmod 777 "$PILOTS"
check_cmd ""
echo -ne "${YELLOW}Copie des pilotes dans $MEDIA_AMOVIBLE..... ${NC}"
cp "$PILOTS" "$MEDIA_AMOVIBLE"
check_cmd ""
echo -ne "${YELLOW}Accès au média amovible ($MEDIA_AMOVIBLE)..... ${NC}"
cd $MEDIA_AMOVIBLE
check_cmd ""
echo -ne "${YELLOW}Dézippage de $PILOTS dans $MEDIA_AMOVIBLE..... ${NC}"
unzip $PILOTS
check_cmd "dézippage"
super_echo YELLOW "Permissions sur tous les fichiers de la clé..... " n
chmod -R 777 *
check_cmd ""

super_echo PURPLE "Démontage de la clé usb"
umount_usb "$cle"

super_echo YELLOW "Éjection de $cle..... " n
sudo eject "$cle" > /dev/null 2>&1
check_cmd ""

echo -ne "${YELLOW}Dernières vérifications..... ${NC}"
check_cmd "tout, fin du script"

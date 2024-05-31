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
        super_echo GREEN "OK fichier valide."
    else
        super_echo RED "KO fichier invalide !"
        exit 3
    fi
else
    super_echo RED "KO fichier non existant !"
    exit 4
fi

cle2=""
while true; do 
    super_echo YELLOW "Affichage des disques..... "
    super_echo YELLOW "NAME\t\tSIZE\tTRAN"
    lsblk | grep -E '^sd' | awk '{print "/dev/"$1"\t"$4"\t"$6"\t"$7}' | sort | while read -r line; do
        super_echo WHITE "$line"
    done
    check_cmd ""
    choice_string "Choisissez votre clé USB (première colonne)" cle
    cle2=$(echo "$cle" | sed -s 's/[0-9]*$//')
    super_echo YELLOW "Check si $cle2 est bien un périphérique existant et amovible..... " n
    sleep 1
    if [[ "$(lsblk -no TRAN "$cle2" | tr -d '\n')" = "usb" ]]; then
        super_echo GREEN "OK pour $cle2"
        break
    else
        super_echo RED "KO !\n\t=> $cle2 n'est pas un périphérique existant et amovible !"
    fi
done
i=0
super_echo YELLOW "Démontage de $cle..... " n
if [[ "$(df -h | grep -E "$cle" | wc -l)" -ne 0 ]]; then
    while [ $i -le 10 ]; do
        if [ $i -eq 0 ]; then
            umount "$cle"
        else
            umount "${cle}${i}"
        fi
        if [ $? -eq 0 ]; then
            break
        fi        
        i=$((i+1))
    done
fi
if [ $i -gt 10 ]; then
    super_echo "RED" "KO ! Impossible de démonter $cle. Arrêt du script"
    exit 5
fi

wimlib=$(which wimlib-imagex > /dev/null 2>&1 && echo "OK" || echo "KO")
if [ "$wimlib" = "KO" ]; then
    super_echo YELLOW "Installation de wimtools..... " n
    sudo apt-get install wimtools > /dev/null 2>&1
    check_cmd ""
fi
super_echo "PURPLE" "Téléchargement du tutoriel..... "
download_tuto "main.zip" "naelebk_tuto_woeusb"

super_echo PURPLE "Processus de la création de la clé usb lancé, cela peut prendre du temps, merci de patienter..... "
make_tuto "$iso_file" "$cle2"
check_cmd ""
super_echo GREEN "Terminaison du script, vous pouvez retirer votre clé usb ($cle2) en toute sécurité."

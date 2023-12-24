#!/bin/bash

# Prérequis : git doit être installé sur votre système, et ce script doit être
# exécuté en tant que root !

YELLOW='\033[1;33m'
GREEN='\033[0;32m'
PURPLE='\033[0;35m'
RED='\033[0;31m'
NC='\033[0m'
ME=$LOGNAME
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
        else
            echo -e "${RED}ERREUR pour $1.${NC}"
        fi
    fi
}

install_app() {
    if ! command -v "$1" > /dev/null 2>&1; then
        echo -ne "${YELLOW}Installation de $1..... ${NC}"
        "$package_manager" install -y "$1" > /dev/null 2>&1
        check_cmd $1
    else
        echo -e "${GREEN}OK pour $1 : déjà installé.${NC}"
    fi
}

if [[ "$(whoami)" != "root" ]]; then
	echo -e "${RED}Le script doit être exécuter en tant que superutilisateur (root).${NC}" 
	exit 4
fi

if [[ "$#" -ne 2 ]]; then
    echo "Utilisation : $0 <adresse_email> <gestionnaire de paquet (apt, dnf, pacman....)>"
    exit 1
fi
email="$1"
$package_manager="$2"
install_app "git"
echo -ne "${YELLOW}Configuration de git avec $email.....${NC} "
sudo -u "$ME" git config --global user.email "$email"
check_cmd ""
echo -ne "${YELLOW}Génération clé SSH avec $email.....${NC} "
sudo -u "$ME" ssh-keygen -t rsa -b 4096 -C "$email"
check_cmd ""
cat "/home/$ME/.ssh/id_rsa.pub"
echo -n "Une fois la clé ssh copiée dans votre compte github, appuyez sur la touche ENTRÉE"
read reponse


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

if [[ "$(id -u)" != "0" ]]; then
	echo -e "${RED}Le script doit être exécuté en tant que superutilisateur (root).${NC}" 
	exit 1
fi
if [[ $(ls *.iso | wc -l) -ne 1 ]]; then
    echo -e "${RED}Le répertoire courant ($(pwd)) ne contient aucune image iso ! Il doit en contenir exactement une.${NC}" 
	exit 2
fi

function is_iso_file {
    if file_command_output=$(file "$1" | grep -q "ISO 9660"); then
        return 0
    fi
    return 1
}

iso_file=""
while true; do
    if [[ -n "$1" ]] && [[ "$#" -eq 1 ]]; then
        iso_file="$1"
    else
        echo -e "${YELLOW}Veuillez spécifier le chemin vers le fichier ISO :${NC}"
        read -r iso_file
    fi
    if [[ -f "$iso_file" ]]; then
        if is_iso_file "$iso_file"; then
            echo -e "${GREEN}OK ! $(basename $iso_file) est bien un fichier ISO valide.${NC}"
            break
        else
            echo -e "${RED}Le fichier spécifié n'est pas un fichier ISO valide.${NC}"
        fi
    else
        echo -e "${RED}Le fichier spécifié n'existe pas.${NC}"
    fi
done

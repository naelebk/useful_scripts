#!/bin/bash
ME=$LOGNAME
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
PURPLE='\033[0;35m'
RED='\033[0;31m'
NC='\033[0m'
OUT=scripts.zip
REP_SCRIPTS="useful_scripts-main"

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

updateee() {
    echo -ne "${YELLOW}Update du système..... ${NC}"
    sudo $1 update > /dev/null 2>&1
    check_cmd ""
}


if [[ "$#" -ne 3 ]]; then
    echo -e "${RED}Synopsis : $0 PACKAGE_MANAGER EXTENSION EMAIL_ADRESS${NC}"
    exit 1
fi
if [[ "$(whoami)" != "root" ]]; then
	echo -e "${RED}Le script doit être exécuter en tant que superutilisateur (root).${NC}" 
	exit 4
fi
package_manager=$1
extension=$2
email=$3
# On récupère les 4 scripts nous permettant de faire les différentes configurations
echo -ne "${YELLOW}Récupération des scripts pour installation..... ${NC}"
sudo -u "$ME" curl -LJ -o $OUT https://github.com/naelebk/useful_scripts/archive/refs/heads/main.zip > /dev/null 2>&1
check_cmd ""
echo -ne "${YELLOW}Permissions sur le zip..... ${NC}"
sudo -u "$ME" chmod -R 755 $OUT > /dev/null 2>&1
check_cmd ""
echo -ne "${YELLOW}Dézippage des scripts..... ${NC}"
unzip $OUT > /dev/null 2>&1
check_cmd ""
echo -ne "${YELLOW}Copie des fichiers du répertoire dézippé au répertoire courant..... ${NC}"
cp -r "$REP_SCRIPTS"/* .
check_cmd ""
echo -ne "${YELLOW}Suppression du répertoire créé et du zip..... ${NC}"
rm -rf $OUT $REP_SCRIPTS
check_cmd ""
echo -ne "${YELLOW}Permissions sur tous les fichiers..... ${NC}"
sudo -u "$ME" chmod 755 *.sh > /dev/null 2>&1
check_cmd ""
echo ""
# Maintenant que tous les scripts ont été récupéré, on peut procéder à l'installation complète du système !
if [[ "$1" = "apt" ]]; then
    ./script_install.sh $1 $2
elif [[ "$1" = "dnf" ]]; then
    ./rhel_script_install.sh $1 $2
fi
./git_config.sh $3 $1
updateee $package_manager
echo -ne "${YELLOW}Pilotes nvidia ?${NC} "
read bs
echo -ne "${PURPLE}Êtes vous sûr ? (Oui/Non)${NC} "
read yb
while [ "$(echo "$yb" | tr '[:upper:]' '[:lower:]')" != "oui" ]; do
    echo -ne "${YELLOW}Pilotes nvidia ?${NC} "
    read bs
    echo -ne "${PURPLE}Êtes vous sûr ? (Oui/Non)${NC} "
    read yb
done
if [ "$(echo "$bs" | tr '[:upper:]' '[:lower:]')" = "oui" ]; then
    ./nvidia-config-debian.sh
fi

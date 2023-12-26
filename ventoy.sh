#!/bin/bash
ME=$LOGNAME
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
PURPLE='\033[0;35m'
RED='\033[0;31m'
NC='\033[0m'
OUT=VENTOY.tar.gz
REP="ventoy-1.0.96"
ISO="windows.iso"
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

if [[ "$(whoami)" != "root" ]]; then
	echo -e "${RED}Le script doit être exécuter en tant que superutilisateur (root).${NC}" 
	exit 4
fi

echo -ne "${YELLOW}Récupération des scripts pour installation..... ${NC}"
sudo -u "$ME" curl -LJ -o $OUT https://github.com/ventoy/Ventoy/releases/download/v1.0.96/ventoy-1.0.96-linux.tar.gz > /dev/null 2>&1
check_cmd ""
echo -ne "${YELLOW}Permissions sur le zip..... ${NC}"
sudo -u "$ME" chmod -R 755 $OUT > /dev/null 2>&1
check_cmd ""
echo -ne "${YELLOW}Dézippage des scripts..... ${NC}"
sudo -u "$ME" tar -zxvf $OUT > /dev/null 2>&1
check_cmd ""
echo -ne "${YELLOW}Accès au répertoire $REP..... ${NC}"
sudo -u "$ME" chmod -R 755 $REP/*
cd $REP
check_cmd ""
echo -ne "${YELLOW}Téléchargement de l'image iso de windows ($ISO)..... ${NC}"
sudo -u "$ME" curl -LJ -o $ISO https://software.download.prss.microsoft.com/dbazure/Win10_22H2_French_x64v1.iso?t=f28c89ff-86bb-4472-97fe-8ec34e09b7fd&e=1703526256&h=da41baa623ac6a336762e3ea34dd803c450cb9314b875f02b3be49be4cf90642 > /dev/null 2>&1
check_cmd ""


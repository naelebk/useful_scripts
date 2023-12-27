#!/bin/bash

#################################################################################
# ========================= COPYRIGHT : © Naël EMBARKI © ======================== 
#################################################################################
ME=$LOGNAME
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
PURPLE='\033[0;35m'
RED='\033[0;31m'
NC='\033[0m'
OUT="VENTOY.tar.gz"
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
while [[ -f $OUT ]]; do
    echo -ne "${YELLOW}Suppression de $OUT car déjà existant..... ${NC}"
    sleep 1
    rm -rf $OUT
    check_cmd ""
done
while [[ -d $REP ]]; do
    echo -ne "${YELLOW}Suppression de $REP car déjà existant..... ${NC}"
    sleep 1
    rm -rf $REP
    check_cmd ""
done
echo -ne "${YELLOW}Vérification d'une image iso déjà présente dans le répertoire..... ${NC}"
nb=$(ls *.iso | grep "[wW][iI][nN]" | wc -l)
sleep 1
if [[ $nb -eq 0 ]]; then
    echo -e "${RED}KO => aucune image iso !${NC}"
else
    echo -e "${GREEN}OK.${NC}"
fi
echo -e "${YELLOW}Récupération des scripts pour installation (out : $OUT)..... ${NC}"
sudo -u "$ME" curl -LJ -o $OUT https://github.com/ventoy/Ventoy/releases/download/v1.0.96/ventoy-1.0.96-linux.tar.gz
check_cmd ""
echo -ne "${YELLOW}Permissions sur le zip..... ${NC}"
sleep 1
sudo -u "$ME" chmod -R 755 $OUT > /dev/null 2>&1
check_cmd ""
echo -ne "${YELLOW}Dézippage des scripts..... ${NC}"
sleep 1
sudo -u "$ME" tar -zxvf $OUT > /dev/null 2>&1
check_cmd ""
echo -ne "${YELLOW}Permissions du répertoire $REP..... ${NC}"
sleep 1
sudo -u "$ME" chmod -R 755 $REP/*
check_cmd ""
if [[ $nb -eq 0 ]]; then
    while true; do
        echo -ne "${YELLOW}Quelle version de Windows : 10/11 (tapez juste le numéro de version) ?\n\t=> ${NC}"
        read version
        if [[ "$version" -ne 10 ]] && [[ "$version" -ne 11 ]]; then
            echo -e "{$RED}KO => la version de Windows doit être 10 ou 11 (tapez juste \"10\" ou \"11\")${NC}"
        else
            echo -e "${YELLOW}Téléchargement de l'image iso de Windows $version ($ISO)..... ${NC}"
            if [[ "$version" -eq 11 ]]; then
                sudo -u "$ME" curl -o "$ISO" "https://software.download.prss.microsoft.com/dbazure/Win11_23H2_French_x64v2.iso?t=fd669ec5-2960-4af4-85c4-d46d58d2a258&e=1703700608&h=37b1c443ac637f7e2f2da032c08ecf37769267f60ed7876f6ef630b552445908"
            elif [[ "$version" -eq 10 ]]; then
                sudo -u "$ME" curl -o "$ISO" "https://software.download.prss.microsoft.com/dbazure/Win10_22H2_French_x64v1.iso?t=6b62c234-6b59-4359-bed5-aa2dbd9f2664&e=1703684845&h=3486653607b1123722cd21f78b668479f9b67bd3e81ec80d7367e95b3b2d2eb8"
            fi
            check_cmd ""
            break
        fi
    done
fi
echo -ne "${YELLOW}Accès au répertoire $REP..... ${NC}"
sleep 1
cd $REP
check_cmd ""
cle=""
cle2=""
while true; do 
    echo -e "${YELLOW}Périphérique       Début       Fin  Secteurs Taille Type${NC}"
    sudo fdisk -l | grep -E "^/dev/"
    echo -ne "${YELLOW}Saisissez quel périphérique fera office de clé USB (première colonne)\n\t=>${NC} "
    read cle
    echo -ne "${PURPLE}Êtes vous sûr ? (Oui/Non)${NC} "
    read y20
    echo
    while [ "$(echo "$y20" | tr '[:upper:]' '[:lower:]')" != "oui" ]; do
        echo -e "${YELLOW}Périphérique       Début       Fin  Secteurs Taille Type${NC}"
        sudo fdisk -l | grep -E "^/dev/"
        check_cmd "lister disques"
        echo -ne "${YELLOW}Saisissez quel périphérique fera office de clé USB (première colonne)\n\t=>${NC} "
        read cle
        echo -ne "${PURPLE}Êtes vous sûr ? (Oui/Non)${NC} "
        read y20
    done
    cle2=$(echo $cle | sed -s 's/[0-9]*$//')
    echo -ne "${YELLOW}Check si $cle2 est bien un périphérique existant et amovible..... ${NC}"
    sleep 1
    removable="$(udevadm info --query=property --name=$cle2 | grep -E "ID_USB_MODEL=" | cut -d'=' -f2)"
    if [[ $removable != "EXTERNAL_USB" ]]; then
        echo -e "${RED}KO => $cle2 n'est pas un périphérique existant et amovible !${NC}"
    else
        echo -e "${GREEN}OK pour $cle2${NC}"
        break
    fi
done
if [[ "$(df -h | grep -E "$cle" | wc -l)" -ne 0 ]]; then
    echo -ne "${YELLOW}Démontage de $cle..... ${NC}"
    umount $cle
    check_cmd ""
fi
sudo sh ./Ventoy2Disk.sh -i $cle2
echo -ne "${YELLOW}Montage de $cle dans /media/$ME..... ${NC}"
mount $cle /media/"$ME"
check_cmd ""
if [[ -d "/media/$ME/Ventoy" ]]; then
    echo -ne "${YELLOW}Copie de $ISO dans /media/$ME/Ventoy..... ${NC}"
    cp ../"$ISO" "/media/$ME/Ventoy"
    check_cmd ""
else
    echo -ne "${YELLOW}Copie de $ISO dans /media/$ME (pas Ventoy, car seul media amovible monté actuellement)..... ${NC}"
    cp ../"$ISO" "/media/$ME"
    check_cmd ""
fi

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
# La version est automatiquement mis à jour en fonction des nouvelles versions de ventoy
# Comment est-elle mise à jour : script shell cherchant automatiquement la version, et 
# modifie le présent script avec la nouvelle version
VERSION="1.0.96"
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
        else
            echo -e "${RED}ERREUR pour $1.${NC}"
        fi
    fi
}

if [[ "$(whoami)" != "root" ]]; then
	echo -e "${RED}Le script doit être exécuter en tant que superutilisateur (root).${NC}" 
	exit 4
fi
if [[ "$(ls $ISO | wc -l)" -eq 0 ]]; then
    echo -e "${RED}Erreur, une image ISO au moins doit être présente dans ce répertoire pour exécuter le script !${NC}"
    exit 5
fi
ME=$LOGNAME
# Légère modification par rapport à la vidéo : de si $ME est root (car il ne doit pas être root)
# Pour la bonne exécution de ce script, l'utilisateur "actuellement" connecté doit avoir son /home
# associé, donc on le vérifie
if [[ "$ME" = "root" ]]; then
    ME=$SUDO_USER
    if [[ -z "$ME" ]] || [[ "$ME" = "root" ]]; then
        ME2=$(ls -l /home | grep -E "^d.*\+" | rev | awk '{print $1}' | rev)
        number=$(echo "$ME2" | wc -l)
        if [[ "$number" -ne 1 ]] || [[ ! -d "/home/$ME2" ]]; then
            while true; do
                echo "$ME2"
                echo -ne "${YELLOW}Saisissez votre nom d'utilisateur (parmis ceux ci-dessus, le votre et pas un autre) :${NC} "
                read ME
                echo -ne "${PURPLE}Êtes vous sûr ? (Oui/Non)${NC} "
                read y19
                while [ "$(echo "$y19" | tr '[:upper:]' '[:lower:]')" != "oui" ]; do
                    echo "$ME2"
                    echo -ne "${YELLOW}Saisissez votre nom d'utilisateur (parmis ceux ci-dessus, le votre et pas un autre) :${NC} "
                    read ME
                    echo -ne "${PURPLE}Êtes vous sûr ? (Oui/Non)${NC} "
                    read y19
                done
                if [[ ! -d "/home/$ME" ]]; then
                    echo -e "${RED}KO => $ME doit être un \"VRAI\" utilisateur du système (il doit avoir son /home associé). : \n${NC}${YELLOW}"
                    ls -l /home | grep 'drwx--x---+'
                    echo -ne "\n${NC}"
                else
                    echo -e "${GREEN}OK pour $ME.${NC}"
                    break
                fi
            done
        else
            ME="$ME2"
        fi
    fi
fi
echo -e "${YELLOW}Utilisateur : ${NC}${GREEN}$ME${NC}"
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
echo -e "${YELLOW}Récupération des scripts pour installation (out : $OUT)..... ${NC}"
sudo -u "$ME" curl -LJ -o $OUT "https://github.com/ventoy/Ventoy/releases/download/v$VERSION/ventoy-$VERSION-linux.tar.gz"
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
echo -ne "${YELLOW}Accès au répertoire $REP..... ${NC}"
sleep 1
cd $REP
check_cmd ""
cle=""
cle2=""
while true; do 
    echo -e "${YELLOW}Affichage des disques..... ${NC}"
    echo -e "NAME\tSIZE\tMOUNTPOINTS"
    lsblk | grep -E '^sd' | awk '{print "/dev/"$1" "$4" "$7}' | sort
    check_cmd ""
    echo -ne "${YELLOW}Saisissez quel périphérique fera office de clé USB (première colonne)\n\t=>${NC} "
    read cle
    echo -ne "${PURPLE}Êtes vous sûr ? (Oui/Non)${NC} "
    read y20
    echo
    while [ "$(echo "$y20" | tr '[:upper:]' '[:lower:]')" != "oui" ]; do
        echo -e "${YELLOW}Affichage des disques..... ${NC}"
        echo -e "NAME\tSIZE\tMOUNTPOINTS"
        lsblk | grep -E '^sd' | awk '{print "/dev/"$1" "$4" "$7}' | sort
        check_cmd ""
        echo -ne "${YELLOW}Saisissez quel périphérique fera office de clé USB (première colonne)\n\t=>${NC} "
        read cle
        echo -ne "${PURPLE}Êtes vous sûr ? (Oui/Non)${NC} "
        read y20
    done
    cle2=$(echo $cle | sed -s 's/[0-9]*$//')
    echo -ne "${YELLOW}Check si $cle2 est bien un périphérique existant et amovible..... ${NC}"
    sleep 1
    removable=$(udevadm info --query=property --name=$cle2 | grep -E "ID_USB_MODEL=")
    # Légère modification par rapport à la vidéo : on regarde s'il existe bien un modèle
    # S'il n'en existe pas (autrement dit : $removable ne contient rien) => pas un média amovible
    # Sinon, le média est bien amovible
    if [[ -z "$removable" ]]; then
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
# Modifications du script par rapport à la vidéo : il se peut que le montage ne soit pas bon
# Et si le montage n'est pas bon, on réitère jusqu'à ce qu'il soit bon
# ==========================================================================================
MEDIA_AMOVIBLE="/home/$ME/VENTOY_USB_DIR"
if [[ ! -d "$MEDIA_AMOVIBLE" ]]; then
    echo -ne "${YELLOW}Création du répertoire $MEDIA_AMOVIBLE..... ${NC}"
    sudo -u "$ME" mkdir "$MEDIA_AMOVIBLE"
    check_cmd ""
fi
echo -ne "${YELLOW}Montage de $cle dans $MEDIA_AMOVIBLE..... ${NC}"
i=0
mount "$cle" "$MEDIA_AMOVIBLE" > /dev/null 2>&1
while [[ "$?" -ne 0 ]]; do
    i=$((i+1))
    mount "$cle$i" "$MEDIA_AMOVIBLE" > /dev/null 2>&1
done
if [[ "$i" -eq 0 ]]; then
    check_cmd "montage de $cle"
else
    check_cmd "montage de $cle($i)"
fi
# ==========================================================================================
cd ..
for file in "./$ISO"; do
    echo -ne "${YELLOW}Copie de $(basename $file) dans $MEDIA_AMOVIBLE..... ${NC}" 
    cp $file $MEDIA_AMOVIBLE
    check_cmd "$(basename $file)"
done
echo -ne "${YELLOW}Récupération des pilotes RST Floppy pour détection des disques (préventif)..... ${NC}"
sudo -u "$ME" curl -o "$PILOTS" https://downloadmirror.intel.com/771904/RST_F6_Floppy-Win10_Win11-18.6.1.1016.1.zip
check_cmd ""
echo -ne "${YELLOW}Copie des pilotes dans $MEDIA_AMOVIBLE..... ${NC}"
sleep 1
cp $PILOTS $MEDIA_AMOVIBLE
check_cmd ""
echo -ne "${YELLOW}Accès au média amovible ($MEDIA_AMOVIBLE)..... ${NC}"
sleep 1
cd $MEDIA_AMOVIBLE
check_cmd ""
echo -ne "${YELLOW}Dézippage de $PILOTS dans $MEDIA_AMOVIBLE..... ${NC}"
sleep 1
unzip $PILOTS
check_cmd "dézippage"
echo -ne "${YELLOW}Dernières vérifications..... ${NC}"
check_cmd "tout, fin du script"

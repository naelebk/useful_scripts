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
VERSION="1.0.97"
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

if [[ "$(whoami)" != "root" ]]; then
	echo -e "${RED}Le script doit être exécuter en tant que superutilisateur (root).${NC}" 
	exit 4
fi
if [[ -z $(file $ISO | grep -E "ISO") || "$(ls $ISO | wc -l)" -eq 0 ]]; then
    echo -e "${RED}Erreur, au moins une image ISO doit être présente dans CE répertoire pour exécuter le script !${NC}"
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
if ! command -v curl >/dev/null 2>&1; then
	echo -ne "${YELLOW}Curl n'est pas installé ! Installation..... ${NC}"
    if command -v apt > /dev/null 2>&1; then
        apt-get install curl
        if [[ -z $(which blkid) ]]; then
            apt-get install util-linux
        fi
    elif command -v dnf > /dev/null 2>&1; then
        dnf install curl
        if [[ -z $(which blkid) ]]; then
            dnf install util-linux
        fi
    elif command -v pacman > /dev/null 2>&1; then
        pacman -S curl
        if [[ -z $(which blkid) ]]; then
            pacman -S util-linux
        fi
    else
        echo -e "${RED}KO !${NC}"
        exit 1
    fi
    check_cmd "installation de curl"
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
cle2=""
while true; do 
    echo -e "${YELLOW}Affichage des disques..... ${NC}"
    echo -e "NAME\t\tSIZE\tTRAN"
    lsblk | grep -E '^sd' | awk '{print "/dev/"$1"\t"$4"\t"$6"\t"$7}' | sort
    check_cmd ""
    choice_string "Choisissez votre clé USB (première colonne)" cle
    cle2=$(echo $cle | sed -s 's/[0-9]*$//')
    echo -ne "${YELLOW}Check si $cle2 est bien un périphérique existant et amovible..... ${NC}"
    sleep 1
    if [[ "$(lsblk -no TRAN "$cle2" | tr -d '\n')" = "usb" ]]; then
        echo -e "${GREEN}OK pour $cle2${NC}"
        break
    else
        echo -e "${RED}KO !\n\t=> $cle2 n'est pas un périphérique existant et amovible !${NC}"
    fi
done
if [[ "$(df -h | grep -E "$cle" | wc -l)" -ne 0 ]]; then
    echo -ne "${YELLOW}Démontage de $cle..... ${NC}"
    umount $cle
    check_cmd ""
fi
echo -ne "${YELLOW}Lancement du script de ventoy..... ${NC}"
sudo sh ./Ventoy2Disk.sh -i $cle2
check_cmd ""
if [[ -z "$(/sbin/blkid "$cle2*" | grep VTOYEFI)" ]]; then
    echo -e "${PURPLE}Arrêt du script....${NC}"
    exit 2
fi
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
sudo -u "$ME" curl -o "$PILOTS" "https://raw.githubusercontent.com/naelebk/useful_scripts/main/PILOTS.zip"
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
echo -ne "${YELLOW}Démontage du système de fichier..... ${NC}"
cd ../ && sudo umount "$MEDIA_AMOVIBLE"
check_cmd "démontage propre de la clé usb"
echo -ne "${YELLOW}Dernières vérifications..... ${NC}"
check_cmd "tout, fin du script"

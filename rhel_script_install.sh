#!/bin/bash

# Prérequis : 
# - exécuter le script en tant que root !
# - ce script ne fonctionne qu'avec des bases RHEL, autre script pour bases Debian et autres

YELLOW='\033[1;33m'
GREEN='\033[0;32m'
PURPLE='\033[0;35m'
RED='\033[0;31m'
NC='\033[0m'
ME=$(whoami)
if ! command -v dnf >/dev/null 2>&1; then
	echo -e "${RED}Le système doit être basé sur RHEL pour exécuter le script.${NC}" 2>&1
	exit 3
fi
if [ "$ME" != "root" ]; then
	echo -e "${RED}Le script doit être exécuter en tant que superutilisateur (root).${NC}" 
	exit 4
fi
if [ "$ME" = "root" ]; then
	ME="nael"
fi
directory="/home/$ME/Téléchargements"
cd "$directory"

package_manager="dnf"
extension="rpm"
echo -e "${YELLOW}Gestionnaire utilisé : $package_manager${NC}"
echo -e "${YELLOW}Extension standard : $extension${NC}\n"

# Ajout des dépôts RPM fusion
echo -e "\n${YELLOW}-----------------------Ajout des dépôts RPM Fusion (free + nonfree)-----------------------${NC}\n"
$package_manager update
$package_manager install http://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$("$extension" -E %fedora).noarch.$extension
$package_manager update
$package_manager install gstreamer1-libav gstreamer1-vaapi gstreamer1-plugins-{good,good-extras,ugly} -y && $package_manager install gstreamer1-plugins-bad-free gstreamer1-plugins-bad-freeworld -y
if [ ! -f "$directory/chrome.$extension" ]; then
    wget "https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.$extension" -O "$directory/chrome.$extension"
else
    echo -e "\n${PURPLE}Le fichier $directory/chrome.$extension existe déjà.${NC}\n"
fi

if [ ! -f "$directory/viv.$extension" ]; then
    wget "https://downloads.vivaldi.com/stable/vivaldi-stable-6.1.3035.75-1.x86_64.$extension" -O "$directory/viv.$extension"
else
    echo -e "\n${PURPLE}Le fichier $directory/viv.$extension existe déjà.${NC}\n"
fi

# Discord sur les systèmes basés sur RedHat, le paquet RPM de Discord n'existe pas
"$package_manager" install https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$("$extension" -E %fedora).noarch.$extension
"$package_manager" update
"$package_manager" install discord
echo -e "\n${GREEN}Discord installé avec succès !${NC}\n"
sleep 1

echo -e "\n${YELLOW}-----------------------Installation des fichiers .$extension-----------------------${NC}\n"
echo "Application non installées :" >> /home/"$ME"/error.log
for file in "$directory"/*."$extension"; do
    chmod 755 "$file"
    echo -e "\n${YELLOW}Installation de $file${NC}\n"
    "$package_manager" install "$file" -y
    if [ "$?" -eq 0 ]; then
        echo -e "\n${GREEN}$file installé avec succès !${NC}\n"
    else
        echo -e "\n${RED}Erreur lors de l'installation de $file.${NC}\n"
	echo "$file" >> /home/"$ME"/error.log
    fi
    sleep 2
done

rm -f "$directory"/*."$extension"
if [ "$?" -eq 0 ]; then
    echo -e "\n${GREEN}Fichiers .$extension supprimés avec succès !${NC}\n"
else
    echo -e "\n${RED}Erreur lors de la suppression de certains fichiers .$extension.${NC}\n" 
fi

echo -e "\n${YELLOW}-----------------------Installation des fichiers avec $package_manager-----------------------${NC}\n"

# Activation de php8.1
RHEL_RELEASE=$(cat /etc/redhat-release | cut -d ' ' -f3)
$package_manager update
$package_manager install https://rpms.remirepo.net/fedora/remi-release-"$RHEL_RELEASE"."$extension"
$package_manager module reset php
$package_manager module install php:remi-8.1
$package_manager update
yum update

# Applications à installer avec le gestionnaire de paquets défini avant
applications="epiphany-browser libreoffice texlive-full texmaker obs-studio gnome-tweaks audacity htop neofetch nano openjdk-17-jdk-headless ssh sshfs sshpass gcc gpg vlc timeshift flatpak celluloid kdenlive"
for app in $applications; do
    # Vérifier si l'application est déjà installée
    if ! command -v "$app" >/dev/null 2>&1; then
        echo -e "\n${YELLOW}Installation de $app${NC}\n"
        "$package_manager" install "$app"
        if [ "$?" -eq 0 ]; then
            echo -e "\n${GREEN}$app installé avec succès !${NC}\n"
        else
            echo -e "\n${RED}Erreur lors de l'installation de $app.${NC}\n"
	        echo "$app" >> /home/"$ME"/error.log
        fi
        sleep 2
    else
        echo -e "\n${PURPLE}$app est déjà installé.${NC}\n"
        sleep 2
    fi
done

echo -e "\n${YELLOW}-----------------------Installation des flatpaks-----------------------${NC}\n"

# Activation des flatpaks
flatpak remote-delete --force flathub
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# Applications à installer avec flatpak
# Evince : lecteur pdf de gnome
flatpaks="com.github.unrud.VideoDownloader flathub com.spotify.Client VSCodium Zotero evince"
for fl in $flatpaks; do
    if [ $(flatpak list | grep -E "$fl" | wc -l) -eq 0 ] ; then
        echo -e "\n${YELLOW}Installation de $fl${NC}\n"
        flatpak install flathub "$fl"
        if [ "$?" -eq 0 ]; then
            echo -e "\n${GREEN}$fl installé avec succès !${NC}\n"
        else
            echo -e "\n${RED}Erreur lors de l'installation de $fl.${NC}\n"
	        echo "$fl" >> /home/"$ME"/error.log
        fi
        sleep 2
    else
        echo -e "\n${PURPLE}$fl est déjà installé.${NC}\n"
        sleep 2
    fi
done

# Nettoyer les dépendances inutiles
"$package_manager" -y autoremove
if [ "$?" -eq 0 ]; then
    echo -e "\n${GREEN}Nettoyage effectué avec succès !${NC}\n"
    echo -e "\n${GREEN}Terminaison du script avec un code de retour de 0.${NC}\n"
else
    echo -e "\n${RED}Erreurs à certains endroits, code de retour : $?.${NC}\n" 
fi

#!/bin/dash

# Prérequis :
# - exécuter le script en tant que root !
# - ne fonctionne qu'avec des bases Debian (autre script pour bases RHEL et autres bases)

#add-apt-repository https://repo.vivaldi.com/stable/deb/
#add-apt-repository http://ppa.launchpad.net/tomtomtom/woeusb/ubuntu
#add-apt-repository http://repository.spotify.com
#add-apt-repository http://ppa.launchpad.net/flatpak/stable/ubuntu
#add-apt-repository http://ppa.launchpad.net/graphics-drivers/ppa/ubuntu
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
PURPLE='\033[0;35m'
RED='\033[0;31m'
NC='\033[0m'
if ! command -v apt >/dev/null 2>&1; then
	echo "${RED}Erreur : le système doit être basé sur Debian pour exécuter le script.${NC}" 2>&1
	exit 3
fi
ME=$(whoami)
if [ "$ME" != "root" ]; then
        echo "${RED}Erreur : le script doit être exécuté en tant que superutilisateur (root).${NC}" 2>&1
        exit 4
fi
if [ "$ME" = "root" ]; then
	ME="nael"
fi
directory="/home/$ME/Téléchargements"
cd "$directory"

package_manager="apt"
extension="deb"
echo "${YELLOW}Gestionnaire utilisé : $package_manager${NC}"
echo "${YELLOW}Extension standard : $extension${NC}\n"    
if [ ! -f "$directory/chrome.$extension" ]; then
    wget "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.$extension" -O "$directory/chrome.$extension"
else
    echo "\n${PURPLE}Le fichier $directory/chrome.$extension existe déjà.${NC}\n"
fi
if [ ! -f "$directory/discord.$extension" ]; then
    wget https://discordapp.com/api/download?platform=linux -O "$directory/discord.$extension"
else 
    echo "\n${PURPLE}Le fichier $directory/discord.$extension existe déjà.${NC}\n"
fi
if [ ! -f "$directory/viv.$extension" ]; then
    wget "https://downloads.vivaldi.com/stable/vivaldi-stable_5.6.2867.58-1_amd64.$extension" -O "$directory/viv.$extension"
else
    echo "\n${PURPLE}Le fichier $directory/viv.$extension existe déjà.${NC}\n"
fi


echo "\n${YELLOW}-----------------------Installation des fichiers .$extension-----------------------${NC}\n"
echo "Applications non installées :" >> /home/"$ME"/error.log
for file in "$directory"/*."$extension"; do
    chmod 755 "$file"
    echo "\n${YELLOW}Installation de $file${NC}\n"
    "$package_manager" install "$file" -y
    if [ "$?" -eq 0 ]; then
        echo "\n${GREEN}$file installé avec succès !${NC}\n"
    else
        echo "\n${RED}Erreur lors de l'installation de $file.${NC}\n" 
	echo "$file" >> /home/"$ME"/error.log
    fi
    sleep 2
done
rm -f "$directory"/*."$extension"
if [ "$?" -eq 0 ]; then
    echo "\n${GREEN}Fichiers .$extension supprimés avec succès !${NC}\n"
else
    echo "\n${RED}Erreur lors de la suppression de certains fichiers .$extension.${NC}\n" 
fi

echo "\n${YELLOW}-----------------------Installation des fichiers avec $package_manager-----------------------${NC}\n"

# Activation de php8.1
$package_manager update
$package_manager install ca-certificates apt-transport-https software-properties-common wget curl lsb-release
curl -sSL https://packages.sury.org/php/README.txt | sudo bash -x
$package_manager update
# Applications à installer avec le gestionnaire de paquet défini avant
applications="epiphany-browser libreoffice texlive-full texmaker obs-studio gnome-tweaks audacity htop neofetch nano openjdk-17-jdk-headless ssh sshfs sshpass gcc valgrind gpg php8.1 vlc timeshift flatpak celluloid kdenlive"
for app in $applications; do
    # Vérifier si l'application est déjà installée
    if ! command -v "$app" >/dev/null 2>&1; then
        echo "\n${YELLOW}Installation de $app${NC}\n"
        "$package_manager" install "$app"
        if [ "$?" -eq 0 ]; then
            echo "\n${GREEN}$app installé avec succès !${NC}\n"
        else
            echo "\n${RED}Erreur lors de l'installation de $app.${NC}\n"
	    echo "$app" >> /home/"$ME"/error.log
        fi
        sleep 2
    else
        echo "\n${PURPLE}$app est déjà installé${NC}\n"
        sleep 2
    fi
done


echo "\n${YELLOW}-----------------------Installation des flatpaks-----------------------${NC}\n"

#Activation des flatpaks
flatpak remote-delete --force flathub
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
# Application à installer avec flatpak
# Evince : lecteur pdf de gnome
flatpaks="com.github.unrud.VideoDownloader flathub com.spotify.Client VSCodium Zotero evince"
for fl in $flatpaks; do
    if [ $(flatpak list | grep -E "$fl" | wc -l) -eq 0 ] ; then
        echo "\n${YELLOW}Installation de $fl${NC}\n"
        flatpak install flathub "$fl"
        if [ "$?" -eq 0 ]; then
            echo "\n${GREEN}$fl installé avec succès !${NC}\n"
        else
            echo "\n${RED}Erreur lors de l'installation de $fl.${NC}\n"
	    echo "$fl" >> /home/"$ME"/error.log
        fi
        sleep 2
    else
        echo "\n${PURPLE}$fl est déjà installé${NC}\n"
        sleep 2
    fi
done

# Nettoyer les dépendances inutiles
"$package_manager" -y autoremove
if [ "$?" -eq 0 ]; then
    echo "\n${GREEN}Nettoyage effectué avec succès !${NC}\n"
    echo "\n${GREEN}Terminaison du script avec un code de retour de 0.${NC}\n"
else
    echo "\n${RED}Erreurs à certains endroits, code de retour : $?.${NC}\n" 
fi

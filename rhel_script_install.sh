#!/bin/bash

# Prérequis : 
# - exécuter le script en tant que root !
# - ce script ne fonctionne qu'avec des bases RHEL, autre script pour bases Debian et autres

YELLOW='\033[1;33m'
GREEN='\033[0;32m'
PURPLE='\033[0;35m'
RED='\033[0;31m'
NC='\033[0m'
ME=$LOGNAME

package_manager="dnf"
extension="rpm"

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
            echo "$1" >> /home/"$ME"/error.log
        fi
    fi
}

updateee() {
    echo -ne "${YELLOW}Update du système..... ${NC}"
    sudo $package_manager update > /dev/null 2>&1
    check_cmd ""
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

install_fl() {
    if ! command -v "$1" > /dev/null 2>&1; then
        echo -ne "${YELLOW}Installation de $1..... ${NC}"
        flatpak install -y "$1" > /dev/null 2>&1
        check_cmd $1
    else
        echo -e "${GREEN}OK pour $1 : déjà installé.${NC}"
    fi
}

if ! command -v dnf >/dev/null 2>&1; then
	echo -e "${RED}Le système doit être basé sur RHEL pour exécuter le script.${NC}" 2>&1
	exit 3
fi
if [[ "$(whoami)" != "root" ]]; then
	echo -e "${RED}Le script doit être exécuter en tant que superutilisateur (root).${NC}" 
	exit 4
fi
directory="/home/$ME/Téléchargements"
cd "$directory"
echo -e "${YELLOW}Gestionnaire utilisé : $package_manager${NC}"
echo -e "${YELLOW}Extension standard : $extension${NC}\n"

# Ajout des dépôts RPM fusion
echo -e "\n${YELLOW}-----------------------Ajout des dépôts RPM Fusion (free + nonfree)-----------------------${NC}\n"

updateee
echo -ne "${YELLOW}Récupération du dépôt RPM fusion..... ${NC}"
$package_manager install http://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$("$extension" -E %fedora).noarch.$extension > /dev/null 2>&1
check_cmd ""
updateee
echo -ne "${YELLOW}Installation des dépôts RPM Fusion..... ${NC}"
$package_manager install gstreamer1-libav gstreamer1-vaapi gstreamer1-plugins-{good,good-extras,ugly} -y > /dev/null 2>&1 && $package_manager install gstreamer1-plugins-bad-free gstreamer1-plugins-bad-freeworld -y > /dev/null 2>&1
check_cmd "installation dépôts RPM fusion"
echo -ne "${YELLOW}Récupération de google chrome..... ${NC}"
wget "https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.$extension" -O "$directory/chrome.$extension"  > /dev/null 2>&1
check_cmd "google-chrome"
echo -ne "${YELLOW}Récupération de vivaldi..... ${NC}"
wget "https://downloads.vivaldi.com/stable/vivaldi-stable-6.1.3035.75-1.x86_64.$extension" -O "$directory/viv.$extension"  > /dev/null 2>&1
# Discord sur les systèmes basés sur RedHat, le paquet RPM de Discord n'existe pas
echo -ne "${YELLOW}Récupération de discord..... ${NC}"
"$package_manager" install https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$("$extension" -E %fedora).noarch.$extension > /dev/null 2>&1
check_cmd "discord"
updateee
echo -ne "${YELLOW}Installation de discord..... ${NC}"
"$package_manager" install discord > /dev/null 2>&1
check_cmd "installation de discord"

echo -e "\n${YELLOW}-----------------------Installation des fichiers .$extension-----------------------${NC}\n"
echo "Application non installées :" >> /home/"$ME"/error.log
for file in "$directory"/*."$extension"; do
    chmod 755 "$file"
    install_app $file
done

rm -f "$directory"/*."$extension"
if [[ "$?" -eq 0 ]]; then
    echo -e "\n${GREEN}Fichiers .$extension supprimés avec succès !${NC}\n"
else
    echo -e "\n${RED}Erreur lors de la suppression de certains fichiers .$extension.${NC}\n" 
fi

echo -e "\n${YELLOW}-----------------------Installation des fichiers avec $package_manager-----------------------${NC}\n"

# Activation de php8.1
RHEL_RELEASE=$(cat /etc/redhat-release | cut -d ' ' -f3)
updateee
echo -ne "${YELLOW}Installation de remi repo..... ${NC}"
$package_manager install https://rpms.remirepo.net/fedora/remi-release-"$RHEL_RELEASE"."$extension" > /dev/null 2>&1
check_cmd ""
echo -ne "${YELLOW}Module reset php..... ${NC}"
$package_manager module reset php > /dev/null 2>&1
check_cmd ""
echo -ne "${YELLOW}Module install php remi..... ${NC}"
$package_manager module install php:remi-8.1 > /dev/null 2>&1
check_cmd ""
yum update

# Applications à installer avec le gestionnaire de paquets défini avant
applications="gnome-tweaks libreoffice texlive-full texmaker obs-studio audacity htop neofetch nano openjdk-17-jdk-headless ssh sshfs sshpass gcc valgrind clang g++ cmake nodejs racket npm gpg php8.1 vlc timeshift flatpak python3 python3-pip python3.11-venv celluloid virt-manager git apache2 php libapache2-mod-php mariadb-server php-mysql php-curl php-gd php-intl php-json php-mbstring php-xml php-zip php-bcmath"
for app in $applications; do
    install_app $app
done

echo -e "\n${YELLOW}-----------------------Installation des flatpaks-----------------------${NC}\n"

# Activation des flatpaks
echo -ne "\n${YELLOW}Activation de Flathub : ${NC}\n" 
flatpak remote-delete --force flathub > /dev/null > /dev/null 2>&1
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo > /dev/null 2>&1
check_cmd "activation de flathub"

# Applications à installer avec flatpak
# Evince : lecteur pdf de gnome
flatpaks="com.github.unrud.VideoDownloader flathub com.spotify.Client VSCodium Zotero evince"
for fl in $flatpaks; do
    install_fl $fl
done

# Nettoyer les dépendances inutiles
echo -ne "${YELLOW}Nettoyage du système ($package_manager autoremove) : ${NC}"
sudo "$package_manager" -y autoremove > /dev/null 2>&1
check_cmd ""

#!/bin/bash

source biblio.sh

# Prérequis : 
# - exécuter le script en tant que root !
# - ce script ne fonctionne qu'avec des bases RHEL, autre script pour bases Debian et autres

YELLOW='\033[1;33m'
GREEN='\033[0;32m'
PURPLE='\033[0;35m'
RED='\033[0;31m'
NC='\033[0m'

if ! is_root; then
    echo -e "${RED}Erreur : le script doit être exécuté en tant que superutilisateur (root).${NC}" 2>&1
    exit 4
fi

package_manager="dnf"
extension="rpm"
ALL_PACKAGES="$1"
if [ "$#" -eq 3 ]; then
    package_manager="$1"
    extension="$2"
    ALL_PACKAGES="$3"
fi

if [ ! -f "$ALL_PACKAGES" ]; then 
    echo -e "${RED}Le fichier '$ALL_PACKAGES' n'est pas un fichier régulier valide. Terminaison.${NC}"
    exit 1
fi 

if ! command -v dnf >/dev/null 2>&1; then
	echo -e "${RED}Le système doit être basé sur RHEL pour exécuter le script.${NC}" 2>&1
	exit 3
fi
directory="/home/$ME/Téléchargements"
cd "$directory"
echo -e "${YELLOW}Gestionnaire utilisé : $package_manager${NC}"
echo -e "${YELLOW}Extension standard : $extension${NC}\n"

# Ajout des dépôts RPM fusion
echo -e "\n${YELLOW}-----------------------Ajout des dépôts RPM Fusion (free + nonfree)-----------------------${NC}\n"

echo -ne "${YELLOW}Récupération du dépôt RPM fusion..... ${NC}"
$package_manager install http://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$("$extension" -E %fedora).noarch.$extension > /dev/null 2>&1
check_cmd ""
updateee "$package_manager"

echo -ne "${YELLOW}Installation des dépôts RPM Fusion..... ${NC}"
$package_manager install gstreamer1-libav gstreamer1-vaapi gstreamer1-plugins-{good,good-extras,ugly} -y > /dev/null 2>&1 && $package_manager install gstreamer1-plugins-bad-free gstreamer1-plugins-bad-freeworld -y > /dev/null 2>&1
check_cmd "installation dépôts RPM fusion"
updateee "$package_manager"

echo -ne "${YELLOW}Récupération de google chrome..... ${NC}"
wget "https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.$extension" -O "$directory/chrome.$extension"  > /dev/null 2>&1
check_cmd "google-chrome"
updateee "$package_manager"

echo -ne "${YELLOW}Récupération de vivaldi..... ${NC}"
wget "https://downloads.vivaldi.com/stable/vivaldi-stable-6.1.3035.75-1.x86_64.$extension" -O "$directory/viv.$extension"  > /dev/null 2>&1
check_cmd "vivaldi"
# Discord sur les systèmes basés sur RedHat, le paquet RPM de Discord n'existe pas
echo -ne "${YELLOW}Récupération de discord..... ${NC}"
"$package_manager" install https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$("$extension" -E %fedora).noarch.$extension > /dev/null 2>&1
check_cmd "discord"

echo -ne "${YELLOW}Installation de discord..... ${NC}"
"$package_manager" install discord > /dev/null 2>&1
check_cmd "installation de discord"

echo -e "\n${YELLOW}-----------------------Installation des fichiers .$extension-----------------------${NC}\n"
echo "Application non installées :" >> /home/"$ME"/error.log
for file in "$directory"/*."$extension"; do
    chmod 755 "$file"
    install_rpm "$file"
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
updateee "$package_manager" 
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

super_echo PURPLE "Installation de toutes les applications avec $package_manager..... "
install_all_apps_from_file "$ALL_PACKAGES"

echo -e "\n${YELLOW}-----------------------Installation des flatpaks-----------------------${NC}\n"

# Activation des flatpaks
echo -ne "\n${YELLOW}Activation de Flathub : ${NC}\n" 
flatpak remote-delete --force flathub > /dev/null > /dev/null 2>&1
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo > /dev/null 2>&1
check_cmd "activation de flathub"

# Applications à installer avec flatpak
# Evince : lecteur pdf de gnome
flatpaks=(
    "com.github.unrud.VideoDownloader" 
    "flathub"
    "kdenlive"
    "com.spotify.Client"
    "VSCodium"
    "Zotero"
    "evince"
)

multiple_choices_by_propositions_array FLS "Choisir les flatpaks que vous voulez installer" "${flatpaks[@]}"
for ((i=0 ; i < ${#FLS[@]} ; i++)); do
    install_flatpak "${FLS[i]}"
done

# Nettoyer les dépendances inutiles
echo -ne "${YELLOW}Nettoyage du système ($package_manager autoremove) : ${NC}"
sudo "$package_manager" -y autoremove > /dev/null 2>&1
check_cmd ""
updateee "$package_manager"

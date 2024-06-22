#!/bin/bash

# Prérequis :
# - exécuter le script en tant que root !
# - ne fonctionne qu'avec des bases Debian (autre script pour bases RHEL et autres bases)

# Appel de notre bibliothèque de fonctions
source biblio.sh

ME=$USER
if [[ -z "$ME" ]] || [[ "$ME" = "root" ]]; then
    ME2=$(ls -l /home | grep -E "^d.*\+" | rev | awk '{print $1}' | rev | head -n 1)
    number=$(echo "$ME2" | wc -l)
    if [[ "$number" -ne 1 ]] || [[ ! -d "/home/$ME2" ]]; then
        ME="nael"
    else
        ME="$ME2"
    fi
fi

if [[ "$(whoami)" != "root" ]]; then
    echo -e "${RED}Erreur : le script doit être exécuté en tant que superutilisateur (root).${NC}" 2>&1
    exit 4
fi
directory="/home/$ME/Téléchargements"
cd "$directory"
package_manager="apt"
extension="deb"
if [ "$#" -eq 2 ]; then
    package_manager="$1"
    extension="$2"
fi
if ! command -v "$package_manager" >/dev/null 2>&1; then
	echo -e "${RED}Erreur : le système doit être basé sur Debian pour exécuter le script.${NC}" 2>&1
	exit 3
fi
echo -e "${YELLOW}Gestionnaire utilisé : ${NC}${GREEN}$package_manager${NC}"
echo -e "${YELLOW}Extension standard : ${NC}${GREEN}$extension${NC}\n"
echo -ne "${YELLOW}Récupération de google chrome..... ${NC}"
wget "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.$extension" -O "$directory/chrome.$extension" > /dev/null 2>&1
check_cmd "google chrome"
echo -ne "${YELLOW}Récupération de discord..... ${NC}"
wget https://discordapp.com/api/download?platform=linux -O "$directory/discord.$extension" > /dev/null 2>&1
check_cmd "discord"
echo -ne "${YELLOW}Récupération de vivaldi..... ${NC}"
wget "https://downloads.vivaldi.com/stable/vivaldi-stable_5.6.2867.58-1_amd64.$extension" -O "$directory/viv.$extension" > /dev/null 2>&1
check_cmd "vivaldi"
echo -e "\n${YELLOW}Installation des fichiers .$extension${NC}\n"
echo "Applications non installées :" >> /home/"$ME"/error.log
for file in "$directory"/*."$extension"; do
    chmod 755 "$file"
    install_app $file "$package_manager"
done
rm -f "$directory"/*."$extension"
if [ "$?" -eq 0 ]; then
    echo -e "\n${GREEN}Fichiers .$extension supprimés avec succès !${NC}"
else
    echo -e "\n${RED}Erreur lors de la suppression de certains fichiers .$extension.${NC}" 
fi

# Activation de php8.1
echo -e "\n${YELLOW}Activation de PHP8.1${NC}\n"
echo -ne "${YELLOW}Update du système..... ${NC}"
sudo $package_manager update > /dev/null 2>&1
check_cmd ""
echo -ne "${YELLOW}Certificats pour php8.1 : ${NC}"
$package_manager install ca-certificates apt-transport-https software-properties-common wget curl lsb-release > /dev/null 2>&1
check_cmd "récupération des certificats pour php8.1"
echo -ne "${YELLOW}Récupération de php8.1 : ${NC}"
curl -sSL https://packages.sury.org/php/README.txt | sudo bash -x > /dev/null 2>&1
check_cmd "récupération de php8.1"
echo -ne "${YELLOW}Update du système : ${NC}" 
sudo $package_manager update > /dev/null 2>&1
check_cmd ""
# Applications à installer avec le gestionnaire de paquet défini avant
echo -e "\n${YELLOW}Installation des fichiers avec $package_manager${NC}\n"
applications=(
    "gnome-tweaks"
    "libreoffice"
    "texlive-full"
    "texmaker"
    "obs-studio"
    "audacity"
    "htop"
    "neofetch"
    "nano"
    "openjdk-17-jdk-headless"
    "ssh"
    "sshfs"
    "sshpass"
    "gcc"
    "valgrind"
    "clang"
    "g++"
    "cmake"
    "nodejs"
    "racket"
    "npm"
    "gpg"
    "php8.1"
    "vlc"
    "timeshift"
    "flatpak"
    "python3"
    "python3-pip"
    "python3.11-venv"
    "celluloid"
    "virt-manager"
    "git"
    "apache2"
    "php"
    "libapache2-mod-php"
    "mariadb-server"
    "php-mysql"
    "php-curl"
    "php-gd"
    "php-intl"
    "php-json"
    "php-mbstring"
    "php-xml"
    "php-zip"
    "php-bcmath"
)
multiple_choices_by_propositions_array APPS "Choisissez les applications que vous voulez installer" "${applications[@]}"
for ((i=0 ; i < ${#APPS[@]} ; i++)); do
    install_app "${APPS[i]}" "$package_manager"
done
echo -ne "${YELLOW}Installation de r7rs-lib (pour racket)..... ${NC}"
sudo -u "$ME" raco pkg install r7rs-lib > /dev/null 2>&1
check_cmd "r7rs-lib"
#Activation des flatpaks
echo -ne "\n${YELLOW}Activation de Flathub : ${NC}\n" 
flatpak remote-delete --force flathub > /dev/null > /dev/null 2>&1
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo > /dev/null 2>&1
check_cmd "activation de flathub"
# Application à installer avec flatpak
# Evince : lecteur pdf de gnome
echo -ne "\n${YELLOW}Installation des flatpaks : ${NC}\n"
flatpaks=(
    "com.github.unrud.VideoDownloader"
    "flathub com.spotify.Client"
    "VSCodium"
    "onlyoffice"
    "Zotero"
    "evince"
)
multiple_choices_by_propositions_array FLS "Choisir les flatpaks que vous voulez installer" "${flatpaks[@]}"
for ((i=0 ; i < ${#FLS[@]} ; i++)); do
    install_app "${FLS[i]}" "flatpak"
done

# Nettoyer les dépendances inutiles
echo -ne "${YELLOW}Nettoyage du système ($package_manager autoremove) : ${NC}"
sudo "$package_manager" -y autoremove > /dev/null 2>&1
check_cmd ""

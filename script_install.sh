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
ME=$LOGNAME
directory="/home/$ME/Téléchargements"
cd "$directory"

check_cmd() {
    if [ $? -eq 0 ] || [ $? -eq 1 ]; then
        if [ -z "$1" ]; then 
            echo "${GREEN}OK.${NC}"
        else 
            echo "${GREEN}OK pour $1.${NC}"
        fi
    else
        if [ -z "$1" ]; then 
            echo "${RED}ERREUR !${NC}"
        else
            echo "${RED}ERREUR pour $1.${NC}"
            echo "$1" >> /home/"$ME"/error.log
        fi
    fi
}

install_app() {
    if ! command -v "$1" > /dev/null 2>&1; then
        echo -n "${YELLOW}Installation de $1..... ${NC}"
        "$package_manager" install -y "$1" > /dev/null 2>&1
        check_cmd $1
    else
        echo "${GREEN}OK pour $1 : déjà installé.${NC}"
    fi
}

install_fl() {
    if ! command -v "$1" > /dev/null 2>&1; then
        echo -n "${YELLOW}Installation de $1..... ${NC}"
        flatpak install -y "$1" > /dev/null 2>&1
        check_cmd $1
    else
        echo "${GREEN}OK pour $1 : déjà installé.${NC}"
    fi
}


if ! command -v apt >/dev/null 2>&1; then
	echo "${RED}Erreur : le système doit être basé sur Debian pour exécuter le script.${NC}" 2>&1
	exit 3
fi
if [ "$(whoami)" != "root" ]; then
    echo "${RED}Erreur : le script doit être exécuté en tant que superutilisateur (root).${NC}" 2>&1
    exit 4
fi

package_manager="apt"
extension="deb"
if [ "$#" -eq 2 ]; then
    package_manager="$1"
    extension="$2"
fi
echo "${YELLOW}Gestionnaire utilisé : ${NC}${GREEN}$package_manager${NC}"
echo "${YELLOW}Extension standard : ${NC}${GREEN}$extension${NC}\n"
echo -n "${YELLOW}Récupération de google chrome..... ${NC}"
wget "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.$extension" -O "$directory/chrome.$extension" > /dev/null 2>&1
check_cmd "google chrome"
echo -n "${YELLOW}Récupération de discord..... ${NC}"
wget https://discordapp.com/api/download?platform=linux -O "$directory/discord.$extension" > /dev/null 2>&1
check_cmd "discord"
echo -n "${YELLOW}Récupération de vivaldi..... ${NC}"
wget "https://downloads.vivaldi.com/stable/vivaldi-stable_5.6.2867.58-1_amd64.$extension" -O "$directory/viv.$extension" > /dev/null 2>&1
check_cmd "vivaldi"
echo "\n${YELLOW}Installation des fichiers .$extension${NC}\n"
echo "Applications non installées :" >> /home/"$ME"/error.log
for file in "$directory"/*."$extension"; do
    chmod 755 "$file"
    install_app $file
done
rm -f "$directory"/*."$extension"
if [ "$?" -eq 0 ]; then
    echo "\n${GREEN}Fichiers .$extension supprimés avec succès !${NC}"
else
    echo "\n${RED}Erreur lors de la suppression de certains fichiers .$extension.${NC}" 
fi

# Activation de php8.1
echo "\n${YELLOW}Activation de PHP8.1${NC}\n"
echo -n "${YELLOW}Update du système..... ${NC}"
sudo $package_manager update > /dev/null 2>&1
check_cmd ""
echo -n "${YELLOW}Certificats pour php8.1 : ${NC}"
$package_manager install ca-certificates apt-transport-https software-properties-common wget curl lsb-release > /dev/null 2>&1
check_cmd "récupération des certificats pour php8.1"
echo -n "${YELLOW}Récupération de php8.1 : ${NC}"
curl -sSL https://packages.sury.org/php/README.txt | sudo bash -x > /dev/null 2>&1
check_cmd "récupération de php8.1"
echo -n "${YELLOW}Update du système : ${NC}" 
sudo $package_manager update > /dev/null 2>&1
check_cmd ""
# Applications à installer avec le gestionnaire de paquet défini avant
echo "\n${YELLOW}Installation des fichiers avec $package_manager${NC}\n"
applications="gnome-tweaks libreoffice texlive-full texmaker obs-studio audacity htop neofetch nano openjdk-17-jdk-headless ssh sshfs sshpass gcc valgrind clang g++ cmake nodejs racket npm gpg php8.1 vlc timeshift flatpak python3 python3-pip python3.11-venv celluloid virt-manager git apache2 php libapache2-mod-php mariadb-server php-mysql php-curl php-gd php-intl php-json php-mbstring php-xml php-zip php-bcmath"
for app in $applications; do
    install_app $app
done
echo -n "${YELLOW}Installation de r7rs-lib (pour racket)..... ${NC}"
sudo -u "$MOI" raco pkg install r7rs-lib > /dev/null 2>&1
check_cmd "r7rs-lib"
#Activation des flatpaks
echo -n "\n${YELLOW}Activation de Flathub : ${NC}\n" 
flatpak remote-delete --force flathub > /dev/null > /dev/null 2>&1
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo > /dev/null 2>&1
check_cmd "activation de flathub"
# Application à installer avec flatpak
# Evince : lecteur pdf de gnome
echo -n "\n${YELLOW}Installation des flatpaks : ${NC}\n"
flatpaks="com.github.unrud.VideoDownloader flathub com.spotify.Client kdenlive VSCodium onlyoffice Zotero evince"
for fl in $flatpaks; do
    install_fl $fl
done

# Nettoyer les dépendances inutiles
echo -n "${YELLOW}Nettoyage du système ($package_manager autoremove) : ${NC}"
sudo "$package_manager" -y autoremove > /dev/null 2>&1
check_cmd ""

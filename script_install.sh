#!/bin/bash

# Prérequis :
# - exécuter le script en tant que root !
# - ne fonctionne qu'avec des bases Debian (autre script pour bases RHEL et autres bases)

# Appel de notre bibliothèque de fonctions
source biblio.sh

if [[ -z "$ME" ]] || [[ $ID_ME -eq $ID_ROOT ]]; then
    ME2=$(ls -l /home | grep -E "^d.*\+" | rev | awk '{print $1}' | rev | head -n 1)
    number=$(echo "$ME2" | wc -l)
    if [[ "$number" -ne 1 ]] || [[ ! -d "/home/$ME2" ]]; then
        ME="nael"
    else
        ME="$ME2"
    fi
fi

if ! is_root; then
    echo -e "${RED}Erreur : le script doit être exécuté en tant que superutilisateur (root).${NC}" 2>&1
    exit 4
fi
directory="/home/$ME/Téléchargements"
cd "$directory"

package_manager="apt"
extension="deb"
ALL_PACKAGES="$1"
if [ "$#" -eq 3 ]; then
    package_manager="$1"
    extension="$2"
    ALL_PACKAGES="$3"
fi

if ! command -v "$package_manager" >/dev/null 2>&1; then
	echo -e "${RED}Erreur : le système doit être basé sur Debian pour exécuter le script.${NC}" 2>&1
	exit 3
fi

if [ ! -f "$ALL_PACKAGES" ]; then 
    echo -e "${RED}Le fichier '$ALL_PACKAGES' n'est pas un fichier régulier valide. Terminaison.${NC}"
    exit 1
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

echo -ne "${YELLOW}Récupération de VSCodium..... ${NC}"
wget "https://github.com/VSCodium/vscodium/releases/download/1.90.2.24171/codium_1.90.2.24171_amd64.deb" -O "$directory/codium.$extension" > /dev/null 2>&1
check_cmd "vscodium"

echo -e "\n${YELLOW}Installation des fichiers .$extension${NC}\n"
echo "Applications non installées :" >> /home/"$ME"/error.log
for file in "$directory"/*."$extension"; do
    chmod 755 "$file"
    install_deb "$file"
done

rm -f "$directory"/*."$extension"
if [ "$?" -eq 0 ]; then
    echo -e "\n${GREEN}Fichiers .$extension supprimés avec succès !${NC}"
else
    echo -e "\n${RED}Erreur lors de la suppression de certains fichiers .$extension.${NC}" 
fi

# Activation de php8.1
echo -e "\n${YELLOW}Activation de PHP8.1${NC}\n"
updateee "$package_manager"

echo -ne "${YELLOW}Certificats pour php8.1 : ${NC}"
$package_manager install ca-certificates apt-transport-https software-properties-common wget curl lsb-release > /dev/null 2>&1
check_cmd "récupération des certificats pour php8.1"

echo -ne "${YELLOW}Récupération de php8.1 : ${NC}"
curl -sSL https://packages.sury.org/php/README.txt | sudo bash -x > /dev/null 2>&1
check_cmd "récupération de php8.1"

updateee "$package_manager"

echo -ne "${YELLOW}Activation de Spotify (1/2).....${NC} "
curl -sS https://download.spotify.com/debian/pubkey_6224F9941A8AA6D1.gpg | sudo gpg --dearmor --yes -o /etc/apt/trusted.gpg.d/spotify.gpg > /dev/null 2>&1
check_cmd ""

echo -ne "${YELLOW}Activation de Spotify (2/2).....${NC} "
echo "deb http://repository.spotify.com stable non-free" | sudo tee /etc/apt/sources.list.d/spotify.list > /dev/null 2>&1
check_cmd ""

updateee "$package_manager"

# Applications à installer avec le gestionnaire de paquet défini avant
echo -e "\n${PURPLE}Installation des paquets avec $package_manager${NC}\n"
install_all_apps_from_file "$ALL_PACKAGES"

# Activation de mariadb
echo -ne "${YELLOW}Activation de MariaDB (1/2)..... ${NC}" 
sudo systemctl start mariadb
check_cmd ""
echo -ne "${YELLOW}Activation de MariaDB (2/2)..... ${NC}" 
sudo systemctl enable mariadb
check_cmd ""

#Activation des flatpaks
echo -ne "\n${YELLOW}Activation de Flathub..... ${NC}" 
flatpak remote-delete --force flathub > /dev/null 2>&1
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo > /dev/null 2>&1
check_cmd "activation de flathub"

# Application à installer avec flatpak
echo -ne "\n${YELLOW}Installation des flatpaks : ${NC}\n"
flatpaks=(
    "com.github.unrud.VideoDownloader"
    "kdenlive"
    "flathub"
)
multiple_choices_by_propositions_array FLS "Choisir les flatpaks que vous voulez installer" "${flatpaks[@]}"
for ((i=0 ; i < ${#FLS[@]} ; i++)); do
    install_flatpak "${FLS[i]}"
done

# Nettoyer les dépendances inutiles
echo -ne "${YELLOW}Nettoyage du système ($package_manager autoremove) : ${NC}"
sudo "$package_manager" -y autoremove > /dev/null 2>&1
check_cmd ""

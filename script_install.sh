#!/bin/bash

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
check_cmd() {
    if [[ $? -eq 0 ]] || [[ $? -eq 1 ]]; then
        if [[ -z "$1" ]]; then 
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

# Fonction permettant de tester si l'argument est un nombre
# Renvoie 0 si c'est le cas, 1 sinon
is_number() {
	if echo "$1" | grep -Eq '^-?[0-9]+$'; then
		return 0
	fi
	return 1
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

aff_couleur_without_special_chars() {
    echo -e "$1\t[$2] $3$4"
}

show_propositions() {
    local qst="$1"
    shift 1
    local props=("$@")
    echo -e "${YELLOW}$qst${NC}"
    for ((i = 0; i < ${#props[@]}; i++)); do
        aff_couleur_without_special_chars "${PURPLE}" "$((i + 1))" "${props[i]}" "${NC}"
    done
}

confirmed_choices=()
# MCQ prend en charge les choix multiples avec intervalle.s
MCQ() {
    local qst="$1"
    shift 1
    local propositions=("$@")
    show_propositions "$qst" "${propositions[@]}"
    action "Vos choix (numéros et séparés par des espaces ou expressions régulières, ou bien \"all\" si vous voulez tout) =>"
    choices="$WWW"
    local regex='^(\[[0-9]+-[0-9]+\]|[0-9]+\[[0-9]+-[0-9]+\]|\[[0-9]+-[0-9]+\][0-9]+|[0-9]+\[[0-9]+-[0-9]+\][0-9]+|\[[0-9]+-[0-9]+\][0-9]+\[[0-9]+-[0-9]+\]|\[[0-9]+-[0-9]+\][0-9]+|\[[0-9]+-[0-9]+\]|[0-9]+\])$'
    IFS=" " read -ra choice_array <<< "$choices"
    for choice in "${choice_array[@]}"; do
        if is_number "$choice" && [ "$choice" -ge 1 ] && [ "$choice" -le "${#propositions[@]}" ]; then
            confirmed_choices+=("${propositions[choice - 1]}")
        elif [[ "$choice" =~ $regex ]]; then
            range="[0-9]"
            group="\\($range\\)"
            groupplus="\\($range\\+\\)"
            intervalle="\\[$group-$group\\]"
            intervalleplus="\\[$groupplus-$groupplus\\]"
            case1="s/$intervalle-$intervalle/\\1\\3 \\2\\4/g"
            case2="s/$intervalle$group/\\1\\3 \\2\\3/g"
            case3="s/$group$intervalle/\\1\\2 \\1\\3/g"
            case4="s/$intervalle/\\1 \\2/g"
            case5="s/$intervalleplus/\\1 \\2/g"
            R=$(echo "$choice" | sed -e "$case1" -e "$case2" -e "$case3" -e "$case4" -e "$case5")
            R1=$(echo "$R" | cut -d' ' -f1)
            R2=$(echo "$R" | cut -d' ' -f2)
            if [[ "$R1" -lt "$R2" ]] && [[ "$R1" -ge 1 ]] && [[ "$R1" -le "${#propositions[@]}" ]] && [[ "$R2" -ge 1 ]] && [[ "$R2" -le "${#propositions[@]}" ]]; then
                for ((i="$R1" ; i <= "$R2" ; i++)); do
                    confirmed_choices+=("${propositions[i - 1]}")
                done
            fi
        elif [[ "$choice" =~ [Aa][Ll][Ll] ]]; then
            echo -e "${GREEN}L'ensemble des propositions a été choisi.${NC}"
            confirmed_choices=("$@")
        fi
    done
    while [ "${#confirmed_choices[@]}" -eq 0 ]; do
        echo -e "${RED}KO => Mauvais choix de nombres ou expressions régulières !${NC}"
        action "Vos choix (numéros et séparés par des espaces ou expressions régulières, ou bien \"all\" si vous voulez tout) =>"
        choices="$WWW"
        IFS=" " read -ra choice_array <<< "$choices"
        confirmed_choices=()
        for choice in "${choice_array[@]}"; do
            if is_number "$choice" && [ "$choice" -ge 1 ] && [ "$choice" -le "${#propositions[@]}" ]; then
                confirmed_choices+=("${propositions[choice - 1]}")
            elif [[ "$choice" =~ $regex ]]; then
                range="[0-9]"
                group="\\($range\\)"
                groupplus="\\($range\\+\\)"
                intervalle="\\[$group-$group\\]"
                intervalleplus="\\[$groupplus-$groupplus\\]"
                case1="s/$intervalle-$intervalle/\\1\\3 \\2\\4/g"
                case2="s/$intervalle$group/\\1\\3 \\2\\3/g"
                case3="s/$group$intervalle/\\1\\2 \\1\\3/g"
                case4="s/$intervalle/\\1 \\2/g"
                case5="s/$intervalleplus/\\1 \\2/g"
                R=$(echo "$choice" | sed -e "$case1" -e "$case2" -e "$case3" -e "$case4" -e "$case5")
                R1=$(echo "$R" | cut -d' ' -f1)
                R2=$(echo "$R" | cut -d' ' -f2)
                if [[ "$R1" -lt "$R2" ]] && [[ "$R1" -ge 1 ]] && [[ "$R1" -le "${#propositions[@]}" ]] && [[ "$R2" -ge 1 ]] && [[ "$R2" -le "${#propositions[@]}" ]]; then
                    for ((i="$R1" ; i <= "$R2" ; i++)); do
                        confirmed_choices+=("${propositions[i - 1]}")
                    done
                fi
            elif [[ "$choice" =~ [Aa][Ll][Ll] ]]; then
                echo -e "${GREEN}L'ensemble des propositions a été choisi.${NC}"
                confirmed_choices=("$@")
            fi
        done
    done
}

multiple_choices_by_propositions_array() {
    local var="$1"
    local qst="$2"
    shift 2
    local propositions=("$@")
    MCQ "$qst" "${propositions[@]}"
    eval "$var=(\"\${confirmed_choices[@]}\")"
}

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
    install_app $file
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
applications=("gnome-tweaks" "libreoffice" "texlive-full" "texmaker" "obs-studio" "audacity" "htop" "neofetch" "nano" "openjdk-17-jdk-headless" "ssh" "sshfs" "sshpass" "gcc" "valgrind" "clang" "g++" "cmake" "nodejs" "racket" "npm" "gpg" "php8.1" "vlc" "timeshift" "flatpak" "python3" "python3-pip" "python3.11-venv" "celluloid" "virt-manager" "git" "apache2" "php" "libapache2-mod-php" "mariadb-server" "php-mysql" "php-curl" "php-gd" "php-intl" "php-json" "php-mbstring" "php-xml" "php-zip" "php-bcmath")
multiple_choices_by_propositions_array APPS "Choisissez les applications que vous voulez installer" "${applications[@]}"
for ((i=0 ; i < ${#APPS[@]} ; i++)); do
    install_app "${APPS[i]}"
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
flatpaks=("com.github.unrud.VideoDownloader" "flathub com.spotify.Client" "VSCodium" "onlyoffice" "Zotero" "evince")
multiple_choices_by_propositions_array FLS "Choisir les flatpaks que vous voulez installer" "${flatpaks[@]}"
for ((i=0 ; i < ${#FLS[@]} ; i++)); do
    install_fl "${FLS[i]}"
done

# Nettoyer les dépendances inutiles
echo -ne "${YELLOW}Nettoyage du système ($package_manager autoremove) : ${NC}"
sudo "$package_manager" -y autoremove > /dev/null 2>&1
check_cmd ""

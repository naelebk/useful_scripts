#!/bin/bash

scripts="scripts-shell"
source biblio.sh

if [[ "$#" -ne 4 ]]; then
    echo -e "${RED}Synopsis : $0 <PACKAGE_MANAGER> <EXTENSION> <EMAIL_ADRESS> <FILE_WITH_ALL_PACKAGES>${NC}"
    exit 1
fi

if ! is_root; then
	echo -e "${RED}Le script doit être exécuter en tant que superutilisateur (root).${NC}" 
	exit 3
fi
package_manager="$1"
extension="$2"
email="$3"
file="$4"

test ! -f $file && (super_echo "RED" "Erreur ! Le fichier '$file' n'est pas un fichier régulier valide" && exit 2)

# First : on configure le git, afin de pouvoir récupérer les autres scripts
git_config "$email" "$package_manager"

# Récupération de tous les projets gits
gits=(
    "useful_scripts"
    "L3"
    "M1"
    "Swiftness"
    "$scripts"
    "bot_discord"
)

cd "/home/$ME/Documents"
for ((i=0 ; i < ${#gits[@]} ; i++)); do
    echo -ne "${YELLOW}Clonage de ${gits[i]}..... ${NC}"
    sudo -u "$ME" git clone "git@github.com:naelebk/${gits[i]}.git"
    check_cmd ""
done

echo -ne "${YELLOW}Permissions sur tous les fichiers..... ${NC}"
sudo -u "$ME" chmod -R 755 * > /dev/null 2>&1
check_cmd ""

echo -ne "${YELLOW}Accès aux scripts d'installation..... ${NC}"
cd $scripts > /dev/null 2>&1
check_cmd ""

echo -ne "${YELLOW}Copie de tous les scripts dans '/home/$ME'..... ${NC}"
cp -r * "/home/$ME" > /dev/null 2>&1
check_cmd ""

echo -ne "${YELLOW}Retour dans '/home/$ME'..... ${NC}"
cd "/home/$ME" > /dev/null 2>&1
check_cmd ""

# Maintenant que tous les scripts ont été récupéré, on peut procéder à l'installation complète du système !
if [ "$package_manager" = "apt" ]; then
    ./script_install.sh "$package_manager" "$extension" "$file"
elif [ "$package_manager" = "dnf" ]; then
    ./rhel_script_install.sh "$package_manager" "$extension" "$file"
else
    echo ""
fi

updateee "$package_manager"

action "Pilotes nvidia ?"
test "$(echo "$WWW" | tr '[:upper:]' '[:lower:]')" = "oui" && ./nvidia-config-debian.sh || echo ""
if [[ -f "add_a_new_service.sh" && -f "init_boot.sh" ]]; then
  ./add_a_new_service.sh "init_boot.sh"
fi


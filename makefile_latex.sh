#!/bin/bash
# Ce programme a pour objectif de générer un makefile automatiquement,
# en se basant sur les fichiers .tex présent dans le répertoire courant

# PS : Dans ce script, le makefile peut être créer dans un répertoire parent,
# mais pas dans un répertoire enfant !
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
PURPLE='\033[0;35m'
RED='\033[0;31m'
NC='\033[0m'

# extension pour le fichier .tex
extension=".tex"
# extension pour le fichier de sortie
out=".pdf"

saut_de_ligne() {
	echo >> "$1"
}

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
        fi
    fi
}

if [ "$#" -eq 0 ]; then
	# On effectue la saisie pour savoir dans quel répertoire on génère le makefile
	echo -ne "${YELLOW}Quel répertoire pour créer le makefile ? (tapez \"pwd\" ou \".\" pour le répertoire courant)${NC} "
	read rep
	case "$(echo "$rep" | tr '[:upper:]' '[:lower:]')" in
		pwd*|".")
			repertoire="$PWD"
			;;
		*)
			if [ ! -d "$rep" ]; then
				echo -e "${RED}Erreur, la saisie ne correspond à aucun répertoire.${NC}"
				echo -e "${RED}--------------- Arrêt du script ---------------${NC}"
				sleep 2
				exit 1
			else
				repertoire="$rep"
			fi
			;;
	esac
else
	if [ -d "$1" ]; then
		repertoire="$1"
	else
		echo -e "${RED}Erreur, répertoire invalide ('$repertoire')${NC}"
		exit 1
	fi
fi
# On affiche le répertoire utilisé
# L'utilisateur a encore la possibilité d'annuler son opération
echo -e "${GREEN}Répertoire utilisé : $repertoire (CTRL + C POUR STOPPER ICI).${NC}"
sleep 3

# Recherche d'un fichier $extension dans $repertoire (au moins 1)
found=false
for file in "$repertoire"/*; do
	test -f "$file" && echo "$file" | grep -Eq "$extension\$" && found=true && break
done

if [ "$found" = false ]; then
	echo "${RED}Il n'y a aucun fichier $extension dans $repertoire.${NC}"
	echo "${RED}--------------- Arrêt du script ---------------${NC}"
	sleep 2
	exit 3
fi
ma="$repertoire/Makefile"
if [ -f "$ma" ]; then
	echo -ne "${YELLOW}Suppression de l'ancien Makefile.....${NC} "
	rm -f "$ma"
	check_cmd ""
fi

echo -ne "${YELLOW}Création du Makefile.....${NC} "
touch "$ma"
check_cmd ""
echo -ne "${YELLOW}Permissions du Makefile.....${NC} "
chmod 755 "$ma"
check_cmd ""

echo "LATEX = pdflatex" >> "$ma"

all_files=""
all_rules=""
for file in "$repertoire"/*${extension}; do
    if [ -f "$file" ]; then
        filename=$(basename "$file" | cut -d. -f1)
        all_files+="${filename}${out} "
		all_rules+="${filename}${out}: ${filename}${extension}\n\n"
    fi
done
echo "TARGETS = $all_files" >> "$ma"
# Règle 'all'
echo "all:\${TARGETS}" >> "$ma"
saut_de_ligne "$ma"
echo -e "%${out}: %.tex %.aux\n\t\${LATEX} \$<" >> "$ma"
saut_de_ligne "$ma"
echo -e "%.aux: %.tex\n\t\${LATEX} \$<\n" >> "$ma"
# Ajout de chaque règle 
echo -e "$all_rules" >> "$ma"
echo -e "clean:\n\trm -f *.aux *.log *.toc *.lof\n\trm -f *.bbl *.blg\n\trm -f *.nav *.out *.snm\n\trm -f *.vrb" >> "$ma"
saut_de_ligne "$ma"
echo -e "mrproper: clean\n\trm -f \${TARGETS}" >> "$ma"
saut_de_ligne "$ma"
echo "remake: mrproper all" >> "$ma"
echo -e "${GREEN}Makefile généré avec succès !${NC}"

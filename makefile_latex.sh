#!/bin/dash
# Ce programme a pour objectif de générer un makefile automatiquement,
# en se basant sur les fichiers .c présent dans le répertoire courant
# (autre script pour les fichiers en C++)

# PS : Dans ce script, le makefile peut être créer dans un répertoire parent,
# mais pas dans un répertoire enfant !
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
PURPLE='\033[0;35m'
RED='\033[0;31m'
NC='\033[0m'

saut_de_ligne() {
	echo >> "$1"
}

if [ "$#" -eq 0 ]; then
	# On effectue la saisie pour savoir dans quel répertoire on génère le makefile
	echo -n "${YELLOW}Quel répertoire pour créer le makefile ? (tapez \"pwd\" ou \".\" pour le répertoire courant)${NC} "
	read rep
	case "$(echo "$rep" | tr '[:upper:]' '[:lower:]')" in
		pwd*|".")
			repertoire="$PWD"
			;;
		*)
			if [ ! -d "$rep" ]; then
				echo "${RED}Erreur, la saisie ne correspond à aucun répertoire.${NC}"
				echo "${RED}--------------- Arrêt du script ---------------${NC}"
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
		echo "${RED}Erreur, répertoire invalide${NC}"
		exit 1
	fi
fi
# On affiche le répertoire utilisé
# L'utilisateur a encore la possibilité d'annuler son opération
echo "${GREEN}Répertoire utilisé : $repertoire (CTRL + C POUR STOPPER ICI).${NC}"
sleep 3
extension=".tex"
found=false
for file in "$repertoire"/*; do
	if [ -f "$file" ] && echo "$file" | grep -E "$extension$"; then
		found=true
		break
	fi
done
if [ "$found" = false ]; then
	echo "${RED}Il n'y a aucun fichier $extension dans $repertoire.${NC}"
	echo "${RED}--------------- Arrêt du script ---------------${NC}"
    sleep 2
	exit 3
fi
ma="$repertoire/Makefile"
if [ -f "$ma" ]; then
	rm -f "$ma"
	if [ "$?" -eq 0 ]; then
		echo "${GREEN}Ancien Makefile supprimé avec succès !${NC}"
		sleep 1
	else
		echo "${RED}Erreur lors de la suppression de l'ancien Makefile. ${NC}"
		echo "${RED}--------------- Arrêt du script ---------------${NC}"
    	sleep 2
		exit 4
	fi
fi
touch "$ma"
if [ "$?" -ne 0 ]; then
	echo "${RED}Erreur lors de la création du Makefile (pas les permissions requises). ${NC}"
	echo "${RED}--------------- Arrêt du script ---------------${NC}"
    sleep 2
	exit 5
fi
chmod 755 "$ma"
if [ "$?" -ne 0 ]; then
	echo "${RED}Erreur lors de l'attribution des permissions du Makefile. ${NC}"
	echo "${RED}--------------- Arrêt du script ---------------${NC}"
    sleep 2
	exit 6
fi
echo "LATEX = pdflatex" >> "$ma"
all_files=""
for file in "$repertoire"/*$extension; do
    if [ -f "$file" ]; then
        filename=$(basename "$file" | cut -d. -f1) # Récupère le nom du fichier sans l'extension
        all_files="$all_files $filename.pdf"
    fi
done
echo "TARGETS = $all_files" >> "$ma"
# Règle 'all'
echo "all:\${TARGETS}" >> "$ma"
saut_de_ligne "$ma"
echo "%.pdf: %.tex %.aux\n\t\${LATEX} \$<" >> "$ma"
saut_de_ligne "$ma"
echo "%.aux: %.tex\n\t\${LATEX} \$<" >> "$ma"
# Ajout de chaque règle 
for file in "$repertoire"/*$extension; do
    if [ -f "$file" ]; then
        filename=$(basename "$file" | cut -d. -f1) # Récupère le nom du fichier sans l'extension
        echo "$filename.pdf: $filename$extension" >> "$ma"
        saut_de_ligne "$ma"
    fi
done
echo "clean:\n\trm -f *.aux *.log *.toc *.lof\n\trm -f *.bbl *.blg\n\trm -f *.nav *.out *.snm\n\trm -f *.vrb" >> "$ma"
saut_de_ligne "$ma"
echo "mrproper: clean\n\trm -f \${TARGETS}" >> "$ma"
saut_de_ligne "$ma"
echo "remake: mrproper all" >> "$ma"
echo "${GREEN}Makefile généré avec succès !${NC}"

#!/bin/bash
# Ce programme a pour objectif de générer un makefile automatiquement,
# en se basant sur les fichiers .c présent dans le répertoire courant

# PS : Dans ce script, le makefile peut être créer dans un répertoire parent,
# mais pas dans un répertoire enfant !
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
PURPLE='\033[0;35m'
RED='\033[0;31m'
NC='\033[0m'

# Explication sur les flags de compilation essentiels pour C :
# -Wall : active la majorité des warnings, utile pour détecter des erreurs potentielles.
# -pthread : inclut la bibliothèque pour gérer les threads, nécessaire pour les programmes multi-threads.
# -Wextra : active encore plus de warnings, pour des vérifications plus strictes.
# -std=c99 : utilise la norme C99, qui inclut des fonctionnalités modernes tout en restant simple.
# -pedantic : adhère strictement à la norme C99, garantissant une portabilité maximale.
# -I. : ajoute le répertoire courant dans les chemins de recherche des fichiers d'en-tête (headers).
# -O2 : optimise le programme pour de meilleures performances sans sacrifier le temps de compilation.
# -g : génère des informations de débogage pour faciliter le suivi des erreurs avec un débogueur.
ALL_FLAGS=("-Wall" "-pthread" "-Wextra" "-std=c99" "-pedantic" "-I." "-O2" "-g")

# On garde l'extension dans une constante, car makefile peut servir pour d'autres scripts !
extension=".c"

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
# Une fois le répertoire choisi, on l'affiche
# L'utilisateur a encore la possibilité d'annuler son opération (3 secondes)
echo -e "${GREEN}Répertoire utilisé : $repertoire (CTRL + C POUR STOPPER ICI).${NC}"
sleep 3

# Recherche d'un fichier $extension dans $repertoire (au moins 1)
found=false
for file in "$repertoire"/*; do
	test -f "$file" && grep -Eq "$extension\$" <<< "$file" && found=true && break
done

if [ "$found" = false ]; then
	echo -e "${RED}Il n'y a aucun fichier $extension dans $repertoire.${NC}"
	echo -e "${RED}--------------- Arrêt du script ---------------${NC}"
	sleep 2
	exit 3
fi
ma="$repertoire/Makefile"
if [ -f "$ma" ]; then
	echo -ne "${YELLOW}Suppression de l'ancien Makefile.....${NC} "
	rm -f "$ma"
	check_cmd ""
fi
echo -ne "${YELLOW}Création du Makefile (\"$ma\").....${NC} "
touch "$ma"
check_cmd ""
echo -ne "${YELLOW}Permissions du Makefile (\"$ma\").....${NC} "
chmod 755 "$ma"
check_cmd ""
echo "CC = gcc" >> "$ma"

flags=""
for flag in "${ALL_FLAGS[@]}"; do flags+="$flag "; done

echo "CFLAGS = $flags" >> "$ma"
saut_de_ligne "$ma"
echo "SRCS = \$(wildcard *.c)" >> "$ma"
echo "OBJS = \$(SRCS:.c=.o)" >> "$ma"
saut_de_ligne "$ma"
echo ".PHONY: clean" >> "$ma"
saut_de_ligne "$ma"
all_files=""
all_rules=""
for file in "${repertoire}"/*${extension}; do
    if [ -f "$file" ]; then
		lm=""
		# -q ici pour ne pas avoir d'affichage de le terminal
		# si code de retour de 0, pattern trouvé et variable lm avec -lm (pour math.h)
		if grep -q math.h < "$file"; then
			lm="-lm"
		fi
		filename=$(basename "$file" | cut -d. -f1)
		all_files="$all_files $filename"
		all_rules="${all_rules}${filename}: ${filename}.o\n\t\$(CC) -o \$@ \$^ ${lm}\n\n"
    fi
done
# Règle 'all'
echo "all:$all_files" >> "$ma"
saut_de_ligne "$ma"
# Ajout de toutes les règles
echo -e "$all_rules" >> "$ma"
# Ajout des dépendances et des règles de compilation
echo "%.o: %.c" >> "$ma"
echo -e "\t\$(CC) \$(CFLAGS) -c \$< -o \$@" >> "$ma"
saut_de_ligne "$ma"
# Ajout d'une règle clean (nettoyage des fichier objets et exécutables (.o + fichier exécutable))
echo "clean:" >> "$ma"
echo -e "\trm -f \$(OBJS)$all_files" >> "$ma"
saut_de_ligne "$ma"
# Petite touche personnelle : remake ; permet de clean puis de tout recompiler (si besoin...)
echo "remake: clean all" >> "$ma"
echo -e "${GREEN}Makefile généré avec succès !${NC}"

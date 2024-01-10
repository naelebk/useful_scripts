#!/bin/bash
ME=$USER
# Légère modification par rapport à la vidéo : de si $ME est root (car il ne doit pas être root)
# Pour la bonne exécution de ce script, l'utilisateur "actuellement" connecté doit avoir son /home
# associé, donc on le vérifie
if [[ -z "$ME" ]] || [[ "$ME" = "root" ]]; then
    ME2=$(ls -l /home | grep -E "^d.*\+" | rev | awk '{print $1}' | rev | head -n 1)
    number=$(echo "$ME2" | wc -l)
    if [[ "$number" -ne 1 ]] || [[ ! -d "/home/$ME2" ]]; then
        ME="nael"
    else
        ME="$ME2"
    fi
fi
DATE=$(date +'%d%m%Y')
TODAY="/home/$ME/$DATE.log"
VENTOY_SCRIPT="/home/$ME/Documents/useful_scripts/ventoy.sh"
PATH_OF_VENTOY=$(echo -e "$VENTOY_SCRIPT" | rev | cut -d'/' -f2- | rev)
ACTUAL_VERSION=$(tr -cd '0-9.' < "$PATH_OF_VENTOY/ventoy_version.txt")
NEW_VERSION=$(curl -sI -L https://github.com/ventoy/Ventoy/releases/latest | grep -i location | awk '{print $2}' | rev | cut -d'/' -f1 | sed 's/v//g' | rev | tr -cd '0-9.')
VV="$PATH_OF_VENTOY/ventoy_version.txt"
if [[ "$ACTUAL_VERSION" != "$NEW_VERSION" ]]; then
	echo -e "\nNouvelle version de ventoy : $NEW_VERSION" >> "$TODAY"
	echo "$NEW_VERSION" > "$VV"
	sed -i "s/VERSION=\"$ACTUAL_VERSION\"/VERSION=\"$NEW_VERSION\"/" "$VENTOY_SCRIPT"
	cd "/home/$ME"
	echo -e "Versionnement de $(basename $TODAY)" >> "$TODAY"
	./version.sh add "$TODAY" "Nouvelle version de ventoy : $NEW_VERSION" >> "$TODAY" 2>&1
	if [[ "$?" -ne 0 ]]; then
		./version.sh commit "$TODAY" "Nouvelle version de ventoy : $NEW_VERSION" >> "$TODAY" 2>&1
	fi
	if [[ "$?" -eq 0 ]]; then
		echo "OK pour versionnement" >> "$TODAY"
	else
		echo "KO pour versionnement" >> "$TODAY"
	fi
	echo "Lancez les commandes suivantes pour versionnement git :" >> "$TODAY"
	echo "cd $PATH_OF_VENTOY" >> "$TODAY"
	echo "./commit.sh \"New V : $NEW_VERSION\"" >> "$TODAY"
else
	echo "Pas de nouvelle version pour ventoy. Version actuelle : $ACTUAL_VERSION" >> "$TODAY"
fi

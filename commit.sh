#!/bin/bash
NC="\e[0m"
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
MAGENTA="\e[35m"
CYAN="\e[36m"
BOLD="\e[1m"
UNDERLINE="\e[4m"
if [[ "$#" -ne 1 ]]; then
	echo -e "${RED}Un argument exactement est obligatoire.${NC}${YELLOW} Synopsis : $0 \"MESSAGE DE COMMIT\"${NC}"
	exit 1
fi
if [[ -z "$1" || "$1" =~ ^[[:space:]]+$ ]]; then
	echo -e "${RED}Le message de commit ne doit pas être vide.${NC}${YELLOW} Synopsis : $0 \"MESSAGE DE COMMIT\"${NC}"
	exit 2
fi
git add *
git commit -m "$1"
git push origin main

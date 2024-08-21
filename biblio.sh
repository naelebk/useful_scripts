YELLOW='\033[1;33m'
GREEN='\033[0;32m'
PURPLE='\033[0;35m'
RED='\033[0;31m'
NC='\033[0m'
ID_ROOT=0
ROOT=$(grep -E ":${ID_ROOT}:" /etc/passwd | cut -d: -f1)
ME=$LOGNAME
ID_ME=$(grep "$ME" < /etc/passwd | cut -d: -f3)

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

updateee() {
    echo -ne "${YELLOW}Update du système..... ${NC}"
    sudo $1 update > /dev/null 2>&1
    check_cmd ""
}

is_root() {
    test $(id -u) -eq $ID_ROOT && return 0 || return 1 
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
    local key="$2"
    if ! command -v "$1" > /dev/null 2>&1; then
        echo -ne "${YELLOW}Installation de $1..... ${NC}"
        "$key" install -y "$1" > /dev/null 2>&1
        check_cmd $1
    else
        echo -e "${GREEN}OK pour $1 : déjà installé.${NC}"
    fi
}

install_deb() {
    echo -ne "${YELLOW}Installation de $1..... ${NC}"
    dpkg -i "$1" > /dev/null 2>&1
    check_cmd "$1"
}

git_config() {
    local email="$1"
    local package_manager="$2"
    install_app "git" "$package_manager"
    install_app "xsel" "$package_manager"
    echo -ne "${YELLOW}Configuration de git avec $email.....${NC} "
    sudo -u "$ME" git config --global user.email "$email"
    check_cmd ""
    echo -ne "${YELLOW}Génération clé SSH avec $email.....${NC} "
    sudo -u "$ME" ssh-keygen -t rsa -b 4096 -C "$email"
    check_cmd ""
    echo -ne "${YELLOW}Copie de la clé ssh dans le presse papier.....${NC} "
    xsel --clipboard < "/home/$ME/.ssh/id_rsa.pub"
    check_cmd ""
    echo -ne "${GREEN}Copiez la clé ssh sur votre compte github, puis appuyez sur la touche ENTRÉE une fois cela fait.${NC}"
    read reponse
}

# Fonction permettant de faire un saut de ligne
saut_de_ligne() {
	echo >> "$1"
}

# Fonction permettant de faire un affichage simple de $1 dans $2
aff() {
	printf "%s\n" "$1" >> "$2"
}

use_systemd() {
    test "$(ps -p 1 -o comm=)" = "systemd" && return 0 || return 1
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
    confirmed_choices=()
    local qst="$1"
    shift 1
    local propositions=("$@")
    show_propositions "$qst" "${propositions[@]}"
    action "Vos choix (numéros et séparés par des espaces ou expressions régulières, ou bien \"all\" si vous voulez tout) =>"
    choices="$WWW"
    local range="[0-9]"
    local rangeplus="$range\\+"
    local nogp_rangeplus="$range+"
    local group="\\($range\\)"
    local groupplus="\\($rangeplus\\)"
    local nogp_intervalle="\[$range-$range\]"
    local nogp_intervalleplus="\[$nogp_rangeplus-$nogp_rangeplus\]"
    local intervalle="\\[$group-$group\\]"
    local intervalleplus="\\[$groupplus-$groupplus\\]"
    local regex="^($nogp_intervalleplus|$nogp_rangeplus$nogp_intervalleplus|$nogp_intervalleplus$nogp_rangeplus|$nogp_rangeplus$nogp_intervalleplus$nogp_rangeplus|$nogp_intervalleplus$nogp_rangeplus$nogp_intervalleplus|$nogp_rangeplus\])$"
    IFS=" " read -ra choice_array <<< "$choices"
    for choice in "${choice_array[@]}"; do
        if is_number "$choice" && [ "$choice" -ge 1 ] && [ "$choice" -le "${#propositions[@]}" ]; then
            confirmed_choices+=("${propositions[choice - 1]}")
        elif [[ "$choice" =~ $regex ]]; then
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


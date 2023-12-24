#!/bin/dash

YELLOW='\033[1;33m'
GREEN='\033[0;32m'
PURPLE='\033[0;35m'
RED='\033[0;31m'
NC='\033[0m'

package_manager="apt"
extension="deb"

check_cmd() {
    if [ $? -eq 0 ] || [ $? -eq 1 ]; then
        if [ -z "$1" ]; then 
            echo "${GREEN}OK.${NC}"
        else 
            echo "${GREEN}OK for $1.${NC}"
        fi
    else
        if [ -z "$1" ]; then 
            echo "${RED}ERROR !${NC}"
        else
            echo "${RED}ERROR for $1 !${NC}"
        fi
    fi
}

install_app() {
    if ! command -v "$1" > /dev/null 2>&1; then
        echo -n "${YELLOW}Installation of $1..... ${NC}"
        "$package_manager" install -y "$1" > /dev/null 2>&1
        check_cmd $1
    else
        echo "${GREEN}OK for $1 : already installed.${NC}"
    fi
}

# Prérequis : le script doit être exécuter en tant que root sur un système
# basé sur Debian (ou bien Debian) !

if ! command -v apt >/dev/null 2>&1; then
    echo "${RED}Error: System must be (based on) Debian to run script.${NC}" 2>&1
    exit 1
fi
ME=$(whoami)
if [ "$ME" != "root" ]; then
    echo "${RED}Error: script must be run as superuser (root).${NC}" 2>&1
    exit 2
fi

# Installation de nvidia-detect (mises à jour faites avant)
echo -n "${YELLOW}System update..... ${NC}"
sudo $package_manager update -y > /dev/null 2>&1
check_cmd ""
echo -n "${YELLOW}System upgrade..... ${NC}"
sudo $package_manager upgrade -y > /dev/null 2>&1
check_cmd ""
install_app "nvidia-detect"
# Vérification de la compatibilité de la carte graphique nvidia
DETECT=$(nvidia-detect | wc -l)
LSPCI=$(lspci | grep -E "VGA|3D" | grep NVIDIA | wc -l)
# Petit erratum : pour $DETECT c'est 1 ligne et non 0
# (Je croyais que c'était redirigé sur l'erreur standard seulement et non la sortie standard)
if [ $DETECT -eq 1 ] || [ $LSPCI -eq 0 ]; then
	echo "${RED}Error, your hardware is not compatible for this installation.${NC}" >&2
	echo "${YELLOW}------------------------- Script exiting... -------------------------${NC}" >&2
	exit 4
fi
# Déctection du pilote à installer
INSTALL=$(nvidia-detect | grep -E "nvidia" | cut -d ' ' -f5)
# Installation du pilote propriétaire
echo -n "${YELLOW}The $INSTALL package will be installed, do you want to continue ? [Yes/No]${NC} "
read rep
case "$(echo "$rep" | tr '[:upper:]' '[:lower:]')" in
	o|y|yes*|yeah*|oui*|ja*)
		install_app $INSTALL
		;;
    n|no*|non*|nope*|nein*|ne*)
		echo "${PURPLE}Nothing done${NC}"
		echo "${YELLOW}------------------------- Script exiting... -------------------------${NC}" >&2
        exit 0
        ;;
    *)
		echo "${PURPLE}$rep : invalid option${NC}"
        echo "${YELLOW}------------------------- Script exiting... -------------------------${NC}" >&2
		exit 6
        ;;
esac

# Installation de nvidia-xconfig
CONFIG="nvidia-xconfig"
install_app $CONFIG
# ATTENTION : utilisation de nvidia-xconfig avec l'option de la technologie OPTIMUS
# Proposition à l'utilisateur sil souhaite ou non utiliser loption --prime à nvidia-xconfig
# À partir du moment où on vous le propose et que vous êtes sûr de votre choix, le créateur du
# script n'est pas responsable des éventuels soucis (on espère que non bien sûr) que vous pouvez
# rencontrer sur votre PC
echo -n "${YELLOW}The $CONFIG will be use now, do you want to add --prime option ? [Yes/No]${NC} "
read rep
case "$(echo "$rep" | tr '[:upper:]' '[:lower:]')" in
    o|y|yes*|yeah*|oui*|ja*)
        echo -n "${YELLOW}Are you sure ? [Yes/No]${NC} "
		read rep2
		case "$(echo "$rep2" | tr '[:upper:]' '[:lower:]')" in
      		o|y|yes*|yeah*|oui*|ja*)
				$CONFIG --prime
				if [ "$?" -ne 0 ]; then
					echo "${RED}Error, cannot apply --prime option to $CONFIG.${NC}" >&2
					echo "${YELLOW}Deleting /etc/X11/xorg.conf file.${NC}" >&2
					rm -f /etc/X11/xorg.conf
				fi
				;;
			*)
				$CONFIG
                if [ "$?" -ne 0 ]; then
                    echo "${RED}Error, cannot use correctly $CONFIG.${NC}" >&2
                    echo "${YELLOW}Deleting /etc/X11/xorg.conf file.${NC}" >&2
					rm -f /etc/X11/xorg.conf
                fi
				;;
	    esac
		;;
    n|no*|non*|nope*|nein*|ne*)
        $CONFIG
        if [ "$?" -ne 0 ]; then
			echo "${RED}Error, cannot use correctly $CONFIG.${NC}" >&2
            echo "${YELLOW}Deleting /etc/X11/xorg.conf file.${NC}" >&2
            rm -f /etc/X11/xorg.conf
        fi
        ;;
    *)
        echo "${PURPLE}$rep : invalid option${NC}"
        echo "${YELLOW}------------------------- Script exiting... -------------------------${NC}" >&2
        exit 8
        ;;
esac
echo -n "${YELLOW}Reboot ? [Yes/No]${NC} "
read rebo
echo -n "${YELLOW}Are you sure ? [Yes/No]${NC} "
read yesorno
while [ "$(echo "$yesorno" | tr '[:upper:]' '[:lower:]')" != "yes" ]; do
    echo -n "${YELLOW}Reboot ? [Yes/No]${NC} "
	read rebo
	echo -n "${YELLOW}Are you sure ? [Yes/No]${NC} "
	read yesorno
done
if [ "$(echo "$rebo" | tr '[:upper:]' '[:lower:]')" = "yes" ]; then
	echo "${YELLOW}Reboot in 5 seconds...${NC}"
	sleep 5
	reboot
else
	echo "${GREEN}Return code : 0${NC}"
	exit 0
fi

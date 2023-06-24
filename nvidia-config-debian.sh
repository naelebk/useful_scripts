#!/bin/dash

YELLOW='\033[1;33m'
GREEN='\033[0;32m'
PURPLE='\033[0;35m'
RED='\033[0;31m'
NC='\033[0m'

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
apt update
apt upgrade
apt install nvidia-detect
if [ "$?" -ne 0 ]; then
	echo "${RED}Error, cannot install nvidia-detect.${NC}" >&2
	echo "${YELLOW}------------------------- Script exiting... -------------------------${NC}" >&2
        sleep 2
        exit 3
fi
# Vérification de la compatibilité de la carte graphique nvidia
DETECT=$(nvidia-detect | wc -l)
LSPCI=$(lspci | grep -E "VGA|3D" | grep NVIDIA | wc -l)
if [ $DETECT -eq 1 ] || [ $LSPCI -eq 0 ]; then
	echo "${RED}Error, your hardware is not compatible for this installation.${NC}" >&2
	echo "${YELLOW}------------------------- Script exiting... -------------------------${NC}" >&2
	sleep 2
	exit 4
fi

# Déctection du pilote à installer
INSTALL=$(nvidia-detect | grep -E "nvidia" | cut -d ' ' -f5)

# Installation du pilote propriétaire
echo -n "${YELLOW}The $INSTALL package will be installed, do you want to continue ? [Yes/No]${NC} "
read rep
case "$(echo "$rep" | tr '[:upper:]' '[:lower:]')" in
	o|y|yes*|yeah*|oui*|ja*)
		apt install $INSTALL
		if [ "$?" -ne 0 ]; then
			echo "${RED}Error, cannot install $INSTALL.${NC}" >&2
        		echo "${YELLOW}------------------------- Script exiting... -------------------------${NC}" >&2
        		sleep 2
        		exit 5
		fi
		;;
        n|no*|non*|nope*|nein*|ne*)
		echo "Nothing done"
		echo "${YELLOW}------------------------- Script exiting... -------------------------${NC}" >&2
        	sleep 2
                exit 0
                ;;
        *)
		echo "${PURPLE}$rep : invalid option${NC}"
                echo "${YELLOW}------------------------- Script exiting... -------------------------${NC}" >&2
                sleep 2
		exit 6
                ;;
esac

# Installation de nvidia-xconfig
CONFIG="nvidia-xconfig"
if ! command -v "$CONFIG" >/dev/null 2>&1; then
	apt install $CONFIG
	if [ "$?" -ne 0 ]; then
		echo "${RED}Error, cannot install $CONFIG.${NC}" >&2
                echo "${YELLOW}------------------------- Script exiting... -------------------------${NC}" >&2
                sleep 2
                exit 7
        fi
fi

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
                sleep 2
                exit 8
                ;;
esac

i=10
while [ $i -gt 0 ]; do
	echo "${YELLOW}System will reboot in $i seconds ! (CTRL + C to cancel).${NC}"
        sleep 1
        i=$(($i - 1))
done

reboot

#!/bin/bash

show_menu(){
    NORMAL=`echo "\033[m"`
    MENU=`echo "\033[36m"` #Blue
    NUMBER=`echo "\033[33m"` #yellow
    FGRED=`echo "\033[41m"`
    RED_TEXT=`echo "\033[31m"`
    ENTER_LINE=`echo "\033[33m"`
    echo -e "${MENU}*********************************************${NORMAL}"
    echo -e "Welcome to Parrot On-Debian Installer Script"
    echo -e "\t\trev 0.2 - 2015-06-10"
    echo -e "${MENU}**${NUMBER} 1)${MENU} Install Core Only ${NORMAL}"
    echo -e "${MENU}**${NUMBER} 2)${MENU} Install Headless Edition ${NORMAL}"
    echo -e "${MENU}**${NUMBER} 3)${MENU} Install Standard Edition ${NORMAL}"
    echo -e "${MENU}**${NUMBER} 4)${MENU} Install Full Edition ${NORMAL}"
    echo -e "${MENU}**${NUMBER} 5)${MENU} Install Home Edition ${NORMAL}"
    echo -e "${MENU}**${NUMBER} 6)${MENU} Install Embedded Edition ${NORMAL}"
    echo -e "${MENU}*********************************************${NORMAL}"
    echo -e "${ENTER_LINE}Please enter a menu option and enter or ${RED_TEXT}enter to exit. ${NORMAL}"
    read opt
}

function option_picked() {
    COLOR='\033[01;31m' # bold red
    RESET='\033[00;00m' # normal white
    MESSAGE=${@:-"${RESET}Error: No message passed"}
    echo -e "${COLOR}${MESSAGE}${RESET}"
}


function core_install() {
	echo -e "deb http://mirrordirector.archive.parrotsec.org/parrot parrot main contrib non-free" > /etc/apt/sources.list.d/parrot.list
	echo -e "# This file is empty, feel free to add here your custom APT repositories\n\n# The standard Parrot repositories are NOT here. If you want to\n# edit them, take a look into\n#                      /etc/apt/sources.list.d/parrot.list\n#                      /etc/apt/sources.list.d/debian.list\n\n\n\n# If you want to change the default parrot repositories setting\n# another localized mirror, then use the command parrot-mirror-selector\n# and see its usage message to know what mirrors are available\n\n\n\n#uncomment the following line to enable the Parrot Testing Repository\n#deb http://us.repository.frozenbox.org/parrot testing main contrib nonfree" > /etc/apt/sources.list
	wget -qO - https://archive.parrotsec.org/parrot/misc/parrotsec.gpg | apt-key add -
	apt-get update
	apt-get -y --force-yes -o Dpkg::Options::="--force-overwrite" install apt-parrot parrot-archive-keyring --no-install-recommends
	parrot-mirror-selector default stable #change it if you want another mirror, launch it without parameters to get the full list of available mirrors
	apt-get update
	apt-get -y --force-yes -o Dpkg::Options::="--force-overwrite" install parrot-core
	apt-get -y --force-yes -o Dpkg::Options::="--force-overwrite" dist-upgrade
	apt-get -y --force-yes -o Dpkg::Options::="--force-overwrite" autoremove
}

function headless_install() {
	apt-get -y --force-yes -o Dpkg::Options::="--force-overwrite" install  parrot-pico
}

function standard_install() {
	apt-get -y --force-yes -o Dpkg::Options::="--force-overwrite" install parrot-interface parrot-tools
}

function full_install() {
	apt-get -y --force-yes -o Dpkg::Options::="--force-overwrite" install parrot-interface parrot-interface-full parrot-tools-full
}

function home_install() {
	apt-get -y --force-yes -o Dpkg::Options::="--force-overwrite" install parrot-interface-full parrot-interface
}

function embedded_install() {
	apt-get -y --force-yes -o Dpkg::Options::="--force-overwrite" install parrot-interface parrot-mini
}



function init_function() {
clear
show_menu
while [ opt != '' ]
    do
    if [[ $opt = "" ]]; then 
            exit;
    else
        case $opt in
        1) clear;
        	option_picked "Installing Core";
		core_install;
		option_picked "Operation Done!";
        	exit;
        ;;

        2) clear;
		option_picked "Installing Headless Edition";
		core_install;
		headless_install;
		option_picked "Operation Done!";
		exit;
            ;;

        3) clear;
		option_picked "Installing Parrot Security OS";
		core_install;
		standard_install;
		option_picked "Operation Done!";
		exit;
            ;;

        4) clear;
		option_picked "Installing Full Edition";
		core_install;
		full_install;
		option_picked "Operation Done!";
		exit;
            ;;
	5) clear;
		option_picked "Installing Home Edition";
		core_install;
		home_install;
		option_picked "Operation Done!";
		exit;
		;;
	6) clear;
		option_picked "Installing Embedded Edition";
		core_install;
		embedded_install;
		option_picked "Operation Done!";
		exit;
	    ;;
        x)exit;
        ;;

	q)exit;
	;;

        \n)exit;
        ;;

        *)clear;
        option_picked "Pick an option from the menu";
        show_menu;
        ;;
    esac
fi
done
}

if [ `whoami` == "root" ]; then
	init_function;
else
	echo "R U Drunk? This script needs to be run as root!"
fi


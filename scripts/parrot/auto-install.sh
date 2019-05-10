
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
	apt-get -y --force-yes -o Dpkg::Options::="--force-overwrite" install  parrot-pico

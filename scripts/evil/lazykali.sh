#Author Alexander Kloster
#apt-get update && apt-get -y dist-upgrade

#!/bin/bash -eux
# To allow for automated installs, we disable interactive configuration steps.
# kali setup script
#
# Sets some required file permissions
#
# This script must be run as root!
#
export DEBIAN_FRONTEND=noninteractive
export DEBCONF_NONINTERACTIVE_SEEN=true

apt-get update && apt-get -y upgrade
apt-get update && apt-get -y dist-upgrade && apt-get autoremove -y && apt-get -y autoclean
out=`grep  "kali-bleeding-edge" /etc/apt/sources.list` &>/dev/null
    echo "" >> /etc/apt/sources.list
    echo '# Bleeding Edge ' >> /etc/apt/sources.list
    echo 'deb http://repo.kali.org/kali kali-bleeding-edge main' >> /etc/apt/sources.list
    apt-get update
    apt-get -y upgrade
apt-get -y install terminator
apt-get -y install xchat
apt-get -y install nautilus-open-terminal
    apt-get install flex &>/dev/null
    apt-get -y install screen hostapd dsniff dhcp3-server ipcalc aircrack-ng
  apt-get install debhelper cmake bison flex libgtk2.0-dev libltdl3-dev libncurses-dev libncurses5-dev libnet1-dev libpcap-dev libpcre3-dev libssl-dev ghostscript python-gtk2-dev libpcap0.8-dev
echo -e "\033[31myou may need this if you broke Openvas with apt-get dist-upgrade\033[m"
apt-get remove --purge greenbone-security-assistant libopenvas6 openvas-administrator openvas-manager openvas-cli openvas-scanner
apt-get install gsd kali-linux kali-linux-full
apt-get -y install flashplugin-nonfree
#apt-get update && apt-get -y dist-upgrade
apt-get update && apt-get -y upgrade
apt-get update && apt-get -y dist-upgrade && apt-get autoremove -y && apt-get -y autoclean
out=`grep  "kali-bleeding-edge" /etc/apt/sources.list` &>/dev/null
    echo "" >> /etc/apt/sources.list
    echo '# Bleeding Edge ' >> /etc/apt/sources.list
    echo 'deb http://repo.kali.org/kali kali-bleeding-edge main' >> /etc/apt/sources.list
    apt-get update
    apt-get -y upgrade
apt-get -y install terminator
apt-get -y install xchat
apt-get -y install nautilus-open-terminal
    apt-get install flex &>/dev/null
    apt-get -y install screen hostapd dsniff dhcp3-server ipcalc aircrack-ng
  apt-get install debhelper cmake bison flex libgtk2.0-dev libltdl3-dev libncurses-dev libncurses5-dev libnet1-dev libpcap-dev libpcre3-dev libssl-dev ghostscript python-gtk2-dev libpcap0.8-dev
echo -e "\033[31myou may need this if you broke Openvas with apt-get dist-upgrade\033[m"
apt-get remove --purge greenbone-security-assistant libopenvas6 openvas-administrator openvas-manager openvas-cli openvas-scanner
apt-get install gsd kali-linux kali-linux-full
apt-get -y install flashplugin-nonfree

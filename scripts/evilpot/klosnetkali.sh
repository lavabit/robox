#Author Alexander Kloster
#apt-get update && apt-get -y dist-upgrade
#http://dev.mysql.com/doc/refman/5.7/en/document-store-setting-up.html
#Section -> "Installing MySQL Shell on Yum-based Systems"
#If you already have the MySQL Yum repository as a software repository on your system, do the following:
# Update the Yum repository release package with the following command: 
# yum update mysql-community-release
# yum install mysql-community-release
#Check with:
# rpm -q  mysql57-community-release
#Seems like a typo in the doc page, should have been:
#sudo yum update mysql57-community-release
# rpm -q  mysql57-community-release
# rpm -q  mysql57-community-release
#yum install mysql-community*
# yum install mysql-community*
to
# yum install mysql-community*5.7*
or just install the package you want (all deps will follow any way), for example for server package:
# yum install mysql-community-server










#!/bin/bash -eux
# To allow for automated installs, we disable interactive configuration steps.
# kali setup script
#
# Sets some required file permissions
#
# This script must be run as root!
#
#
##export domain=example.com
export domain=miskc.org
#export domain=example.com
export DEBIAN_FRONTEND=noninteractive
export DEBCONF_NONINTERACTIVE_SEEN=true
sudo update update --assume-yes && sudo apt --assume-yes install wget
wget -q https://packages.microsoft.com/config/ubuntu/18.04/packages-microsoft-prod.deb
sudo dpkg -i packages-microsoft-prod.deb 
sudo apt update --assume-yes
sudo apt --assume-yes powershell

#To start PowerShell, use the command:

# pwsh
#PowerShell 6.1.1

#https://aka.ms/pscore6-docs
#Type 'help' to get help.

#PS /home/vagrant>
# This script must be run as root!
mkdir /opt/ && cd /opt/
git clone https://github.com/certbot/certbot
/opt/certbot/certbot-auto certonly --standalone --non-interactive --agree-tos --rsa-key-size 4096 --email "admin@$domain" -d "$domain, www.$domain,imap.$domain,pop.$domain,smtp.$domain"
# This script must be run as root!
# This script must be run as root!
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

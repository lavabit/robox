#!/bin/bash

# Check whether the install media is mounted, and if necessary mount it.
if [ ! -f /media/media.repo ]; then
  mount /dev/cdrom /media
fi

# Setup the install DVD as the yum repo location.
cp /media/media.repo /etc/yum.repos.d/media.repo
printf "enabled=1\n" >> /etc/yum.repos.d/media.repo
printf "baseurl=file:///media/\n" >> /etc/yum.repos.d/media.repo

# Import the Red Hat signing key.
rpm --import /media/RPM-GPG-KEY-redhat-release
#
# # Setup the EPEL repo.
# base64 --decode > epel-release-8-0.noarch.rpm <<-EOF
# #########################################################
# # Waiting for EPEL v8... this is a package placeholder. #
# #########################################################
# EOF
#
# # Install the EPEL release RPM.
# yum --assumeyes install epel-release-8-0.noarch.rpm
#
# # Setup the EPEL release signing key.
# rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-8
#
# # Update the EPEL repo to use HTTPS.
# sed -i -e "s/^#baseurl/baseurl/g" /etc/yum.repos.d/epel.repo
# sed -i -e "s/^mirrorlist/#mirrorlist/g" /etc/yum.repos.d/epel.repo
# sed -i -e "s/http:\/\/download.fedoraproject.org\/pub\/epel\//https:\/\/mirrors.kernel.org\/fedora-epel\//g" /etc/yum.repos.d/epel.repo

# Install the basic packages we'd expect to find.
yum --assumeyes install  sudo dmidecode yum-utils bash-completion man man-pages vim-enhanced sysstat bind-utils jwhois wget dos2unix unix2dos lsof telnet net-tools coreutils grep gawk sed curl patch sysstat make cmake libarchive texinfo autoconf automake libtool gcc-c++ libstdc++-devel gcc cpp ncurses-devel glibc-devel glibc-headers kernel-headers psmisc

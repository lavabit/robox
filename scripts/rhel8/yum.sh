#!/bin/bash

# Check whether the install media is mounted, and if necessary mount it.
if [ ! -d /media/BaseOS/ ] || [ ! -d /media/AppStream/ ]; then
  mount /dev/cdrom /media || (printf "\nFailed mount RHEL cdrom.\n"; exit 1)
fi

# Setup the install DVD as the yum repo location.
cat <<-EOF > /etc/yum.repos.d/media.repo
[rhel8-base-media]
name=rhel8-base
baseurl=file:///media/BaseOS/
gpgcheck=1
enabled=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-beta

[rhel8-appstream-media]
name=rhel8-appstream
baseurl=file:///media/AppStream/
gpgcheck=1
enabled=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release
EOF

# Import the Red Hat signing key.
rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-beta
rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release

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
# # Delete the RPM file.
# rm --force epel-release-6.8.noarch.rpm
#
# # Update the EPEL repo to use HTTPS.
# sed -i -e "s/^#baseurl/baseurl/g" /etc/yum.repos.d/epel.repo
# sed -i -e "s/^mirrorlist/#mirrorlist/g" /etc/yum.repos.d/epel.repo
# sed -i -e "s/http:\/\/download.fedoraproject.org\/pub\/epel\//https:\/\/mirrors.kernel.org\/fedora-epel\//g" /etc/yum.repos.d/epel.repo

# Install the basic packages we'd expect to find.
yum --assumeyes install sudo dmidecode yum-utils bash-completion man man-pages vim-enhanced sysstat bind-utils wget dos2unix unix2dos lsof telnet net-tools coreutils grep gawk sed curl patch sysstat make cmake libarchive info autoconf automake libtool gcc-c++ libstdc++-devel gcc cpp ncurses-devel glibc-devel glibc-headers kernel-headers psmisc libcurl libunistring

# Whois is missing from the beta.
# jwhois

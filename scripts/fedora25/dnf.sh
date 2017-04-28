#!/bin/bash


error() {
        if [ $? -ne 0 ]; then
                printf "\n\ndnf failed...\n\n";
                exit 1
        fi
}

# Tell yum to retry 128 times before failing, so unattended installs don't skip packages when errors occur.
# printf "\nretries=128\ndeltarpm=0\nmetadata_expire=0\nmirrorlist_expire=0\n" >> /etc/yum.conf

# Disable IPv6 or dnf will resolve mirror names to IPv6 address and then fail to connect with them.
sysctl net.ipv6.conf.all.disable_ipv6=1

# Update the base install first.
dnf --assumeyes upgrade; error

# Needed to retrieve source code, and other misc system tools.
dnf --assumeyes install vim git wget curl rsync gnupg mlocate sysstat lsof pciutils usbutils; error


# Packages needed beyond a minimal install to build and run magma.
dnf --assumeyes install valgrind valgrind-devel texinfo autoconf automake libtool ncurses-devel gcc-c++ libstdc++-devel gcc cpp glibc-devel glibc-headers kernel-headers mpfr ppl perl perl-Module-Pluggable perl-Pod-Escapes perl-Pod-Simple perl-libs perl-version patch sysstat perl-Time-HiRes make cmake libarchive deltarpm; error

# Grab the required packages from the EPEL repo.
dnf --assumeyes install libbsd libbsd-devel inotify-tools; error

# Boosts the available entropy which allows magma to start faster.
dnf --assumeyes install haveged; error

# The daemon services magma relies upon.
dnf --assumeyes install libevent memcached mariadb mariadb-libs mariadb-server perl-DBI perl-DBD-MySQL; error

# Packages used to retrieve the magma code, but aren't required for building/running the daemon.
dnf --assumeyes install wget git rsync perl-Git perl-Error; error

# These packages are required for the stacie.py script, which requires the python cryptography package (installed via pip).
dnf --assumeyes install python-crypto python-cryptography

# Packages used during the provisioning process and then removed during the cleanup stage.
dnf --assumeyes install sudo dmidecode; error

# Run update a second time, just in case it failed the first time. Mirror timeoutes and cosmic rays
# often interupt the the provisioning process.
dnf --assumeyes upgrade; error

# Reboot onto the new kernel (if applicable).
shutdown --reboot --no-wall +1

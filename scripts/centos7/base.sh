#!/bin/bash

error() {
        if [ $? -ne 0 ]; then
                printf "\n\nyum failed...\n\n";
                exit 1
        fi
}

# Packages needed beyond a minimal install to build and run magma.
yum --assumeyes install valgrind valgrind-devel texinfo autoconf automake libtool ncurses-devel gcc-c++ libstdc++-devel gcc cpp glibc-devel glibc-headers kernel-headers mpfr ppl perl perl-Module-Pluggable perl-Pod-Escapes perl-Pod-Simple perl-libs perl-version patch sysstat perl-Time-HiRes make cmake libarchive; error

# Install the libbsd packages from the EPEL repository, which DSPAM relies upon for the strl functions.
# The entropy daemon is optional, but improves the availability of entropy, which makes magma launch
# and complete her unit tests faster.
yum --assumeyes install libbsd libbsd-devel inotify-tools; error

# Boosts the available entropy which allows magma to start faster.
yum --assumeyes install haveged; error

# The daemon services magma relies upon.
yum --assumeyes install libevent memcached mariadb mariadb-libs mariadb-server perl-DBI perl-DBD-MySQL; error

# Packages used to retrieve the magma code, but aren't required for building/running the daemon.
yum --assumeyes install wget git rsync perl-Git perl-Error; error

# These packages are required for the stacie.py script, which requires the python cryptography package (installed via pip).
yum --assumeyes install python-crypto python-cryptography

# Packages used during the provisioning process and then removed during the cleanup stage.
yum --assumeyes install sudo dmidecode; error

# Run update a second time, just in case it failed the first time. Mirror timeoutes and cosmic rays
# often interupt the the provisioning process.
yum --assumeyes --disablerepo=epel update; error

# Enable and start the daemons.
systemctl enable mariadb
systemctl enable haveged
systemctl enable memcached
systemctl start mariadb
systemctl start haveged
systemctl start memcached

# Close a potential security hole.
systemctl disable remote-fs.target

# Disable kernel dumping.
systemctl disable kdump.service

# Create the clamav user to avoid spurious errors.
useradd clamav

# Setup the mysql root account with a random password.
export PRAND=`openssl rand -base64 18`
mysqladmin --user=root password "$PRAND"

# Allow the root user to login to mysql as root by saving the randomly generated password.
printf "\n\n[mysql]\nuser=root\npassword=$PRAND\n\n" >> /root/.my.cnf

# Change the default temporary table directory or else the schema reset will fail when it creates a temp table.
printf "\n\n[server]\ntmpdir=/tmp/\n\n" >> /etc/my.cnf.d/server-tmpdir.cnf
chcon system_u:object_r:mysqld_etc_t:s0 /etc/my.cnf.d/server-tmpdir.cnf

# Create the mytool user and grant the required permissions.
mysql --execute="CREATE USER mytool@localhost IDENTIFIED BY 'aComplex1'"
mysql --execute="GRANT ALL ON *.* TO mytool@localhost"

# Setup the python path and increase the history size.
printf "export HISTSIZE=\"100000\"\n" > /etc/profile.d/histsize.sh
chcon "system_u:object_r:bin_t:s0" /etc/profile.d/histsize.sh
chmod 644 /etc/profile.d/histsize.sh

# Find out how much RAM is installed, and what 50% would be in KB.
TOTALMEM=`free -k | grep -E "^Mem:" | awk -F' ' '{print $2}'`
HALFMEM=`echo $(($TOTALMEM/2))`

# Setup the memory locking limits.
printf "*    soft    memlock    $HALFMEM\n" > /etc/security/limits.d/50-magmad.conf
printf "*    hard    memlock    $HALFMEM\n" >> /etc/security/limits.d/50-magmad.conf

# Fix the SELinux context.
chcon system_u:object_r:etc_t:s0 /etc/security/limits.d/50-magmad.conf

# Set the timezone to Pacific time.
printf "ZONE=\"America/Los_Angeles\"\n" > /etc/sysconfig/clock

# Output the system vendor string detected.
export SYSPRODNAME=`dmidecode -s system-product-name`
export SYSMANUNAME=`dmidecode -s system-manufacturer`
printf "System Product String:  $SYSPRODNAME\nSystem Manufacturer String: $SYSMANUNAME\n"

#!/bin/bash

error() {
        if [ $? -ne 0 ]; then
                printf "\n\nyum failed...\n\n";
                exit 1
        fi
}


# Disable the broken repositories.
truncate --size=0 /etc/yum.repos.d/CentOS-Media.repo /etc/yum.repos.d/CentOS-Vault.repo

# Tell yum to retry 128 times before failing, so unattended installs don't skip packages when errors occur.
printf "\nretries=128\n" >> /etc/yum.conf

# Ensure a nameserver is being used that won't return an IP for non-existent domain names.
printf "\nnameserver 4.2.2.1\n" > /etc/resolv.conf

# Set the local hostname to resolve properly.
printf "\n127.0.0.1	magma.builder\n\n" >> /etc/hosts

# Update the base install first.
yum --quiet --assumeyes update; error

# Packages needed beyond a minimal install to build and run magma.
yum --quiet --assumeyes install valgrind valgrind-devel texinfo autoconf automake libtool ncurses-devel gcc-c++ libstdc++-devel gcc cloog-ppl cpp glibc-devel glibc-headers kernel-headers libgomp mpfr ppl perl perl-Module-Pluggable perl-Pod-Escapes perl-Pod-Simple perl-libs perl-version patch sysstat perl-Time-HiRes cmake libarchive; error

# Install the libbsd packages from the EPEL repository, which DSPAM relies upon for the strl functions.
# The entropy daemon is optional, but improves the availability of entropy, which makes magma launch 
# and complete her unit tests faster.
yum --quiet --assumeyes --enablerepo=extras install epel-release; error
yum --quiet --assumeyes install libbsd libbsd-devel inotify-tools haveged; error

# The daemon services magma relies upon. 
yum --quiet --assumeyes install libevent memcached mysql mysql-server perl-DBI perl-DBD-MySQL; error 

# Packages used to retrieve the magma code, but aren't required for building/running the daemon.
yum --quiet --assumeyes install wget git rsync perl-Git perl-Error; error

# Packages used during the provisioning process and then removed during the cleanup stage.
yum --quiet --assumeyes install sudo dmidecode yum-utils; error

# Run update a second time, just in case it failed the first time. Mirror timeoutes and cosmic rays 
# often interupt the the provisioning process.
yum --quiet --assumeyes --disablerepo=epel update; error

# Enable and start the daemons.
chkconfig mysqld on
chkconfig haveged on
chkconfig memcached on
service mysqld start
service haveged start
service memcached start

# Disable IPv6 and the iptables module used to firewall IPv6.
chkconfig ip6tables off
printf "\n\nnet.ipv6.conf.all.disable_ipv6 = 1\n" >> /etc/sysctl.conf

# Close a potential security hole.
chkconfig netfs off

# Create the clamav user to avoid spurious errors.
useradd clamav

# Setup the mysql root account with a random password.
export PRAND=`openssl rand -base64 18`
mysqladmin --user=root password "$PRAND"

# Allow the root user to login to mysql as root by saving the randomly generated password.
printf "\n\n[mysql]\nuser=root\npassword=$PRAND\n\n" >> /root/.my.cnf 

# Create the mytool user and grant the required permissions.
mysql --execute="CREATE USER mytool@localhost IDENTIFIED BY 'aComplex1'"
mysql --execute="GRANT ALL ON *.* TO mytool@localhost"
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


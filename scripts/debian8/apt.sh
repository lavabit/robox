#!/bin/bash

error() {
        if [ $? -ne 0 ]; then
                printf "\n\napt failed...\n\n";
                exit 1
        fi
}

# To allow for autmated installs, we truncate the preconfigure option.
truncate --size=0 /etc/apt/apt.conf.d/70debconf; error

# Ensure the server includes any necessary updates.
apt-get update; error
apt-get dist-upgrade; error

# The packages needed to compile magma.
apt-get --assume-yes install gcc g++ gcc-multilib make autoconf automake libtool flex bison gdb valgrind valgrind-dbg libpython2.7 libc6-dev libc++-dev libncurses5-dev libmpfr4 libmpfr-dev patch make cmake libarchive13 libbsd-dev libsubunit-dev libsubunit0 pkg-config; error

# The memcached server.
apt-get --assume-yes install memcached libevent-dev; error

# The postfix server for message relays.
apt-get --assume-yes install postfix postfix-cdb libcdb1 ssl-cert; error

# The mysql client and related utilities.
apt-get --assume-yes install mysql-client mysql-server perl libdbi-perl libmysqlclient18 mysql-common libdbd-mysql-perl; error

# Need to retrieve the source code.
apt-get --assume-yes install git git-man liberror-perl rsync wget; error

# Needed to run the watcher and status scripts.
apt-get --assume-yes install sysstat inotify-tools; error

# Needed to run the stacie script.
apt-get --assume-yes install python-crypto python-cryptography; error

# Boosts the available entropy which allows magma to start faster.
apt-get --assume-yes install haveged; error

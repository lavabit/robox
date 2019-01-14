#!/bin/bash -eux

# To allow for autmated installs, we disable interactive configuration steps.
export DEBIAN_FRONTEND=noninteractive
export DEBCONF_NONINTERACTIVE_SEEN=true

# The mysql client and related utilities.
apt-get --assume-yes install mysql-client mysql-server perl libdbi-perl libmysqlclient18 mysql-common libdbd-mysql-perl

# Setup mysql to start automatically.
systemctl start mysql.service && systemctl enable mysql.service

# Setup the mysql root account with a random password.
export PRAND=`openssl rand -base64 18`
mysqladmin --user=root password "$PRAND"

# Allow the root user to login to mysql as root by saving the randomly generated password.
printf "\n\n[mysql]\nuser=root\npassword=$PRAND\n\n" >> /root/.my.cnf

# Create the mytool user and grant the required permissions.
mysql --execute="CREATE USER mytool@localhost IDENTIFIED BY 'aComplex1'"
mysql --execute="GRANT ALL ON *.* TO mytool@localhost"

#!/bin/bash -eux

# The mysql client and related utilities.
apk add mariadb mariadb-client mariadb-common libaio libgcc libstdc++

# Create the initial database.
/etc/init.d/mariadb setup

# So it gets started automatically.
rc-update add mariadb default && rc-service mariadb start

# Setup the mysql root account with a random password.
export PRAND=`dd if=/dev/urandom count=50 | md5sum | awk -F' ' '{print $1}'`
mysqladmin --user=root password "$PRAND"

# Allow the root user to login to mysql as root by saving the randomly generated password.
printf "\n\n[mysql]\nuser=root\npassword=$PRAND\n\n" >> /root/.my.cnf

# Create the mytool user and grant the required permissions.
mysql --execute="CREATE USER mytool@localhost IDENTIFIED BY 'aComplex1'"
mysql --execute="GRANT ALL ON *.* TO mytool@localhost"

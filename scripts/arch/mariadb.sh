#!/bin/bash -eux

mariadb mariadb-clients libmariadbclient boost-libs jemalloc

# Create the mariadb auth database.
mysql_install_db --user=mysql --basedir=/usr --datadir=/var/lib/mysql

# Setup mariadb to start automatically.
systemctl start mariadb.service && systemctl enable mariadb.service

# Setup the mariadb root account with a random password.
export PRAND=`openssl rand -base64 18`
mysqladmin --user=root password "$PRAND"

# Allow the root user to login to mysql as root by saving the randomly generated password.
printf "\n\n[mysql]\nuser=root\npassword=$PRAND\n\n" >> /root/.my.cnf

# Create the mytool user and grant the required permissions.
mysql --execute="CREATE USER mytool@localhost IDENTIFIED BY 'aComplex1'"
mysql --execute="GRANT ALL ON *.* TO mytool@localhost"

#!/bin/bash -eux

retry() {
  local COUNT=1
  local DELAY=0
  local RESULT=0
  while [[ "${COUNT}" -le 10 ]]; do
    [[ "${RESULT}" -ne 0 ]] && {
      [ "`which tput 2> /dev/null`" != "" ] && [ -n "$TERM" ] && tput setaf 1
      echo -e "\n${*} failed... retrying ${COUNT} of 10.\n" >&2
      [ "`which tput 2> /dev/null`" != "" ] && [ -n "$TERM" ] && tput sgr0
    }
    "${@}" && { RESULT=0 && break; } || RESULT="${?}"
    COUNT="$((COUNT + 1))"

    # Increase the delay with each iteration.
    DELAY="$((DELAY + 10))"
    sleep $DELAY
  done

  [[ "${COUNT}" -gt 10 ]] && {
    [ "`which tput 2> /dev/null`" != "" ] && [ -n "$TERM" ] && tput setaf 1
    echo -e "\nThe command failed 10 times.\n" >&2
    [ "`which tput 2> /dev/null`" != "" ] && [ -n "$TERM" ] && tput sgr0
  }

  return "${RESULT}"
}

# Install MariaDB
retry apt-get install --assumeyes mariadb-client mariadb-server perl libdbi-perl libmariadbclient18 mariadb-common libdbd-mysql-perl

# Setup mysql to start automatically.
systemctl start mariadb.service && systemctl enable mariadb.service

# Setup the mysql root account with a random password.
export PRAND=`openssl rand -base64 18`
mysqladmin --user=root password "$PRAND"

# Allow the root user to login to mysql as root by saving the randomly generated password.
printf "\n\n[mysql]\nuser=root\npassword=$PRAND\n\n" >> /root/.my.cnf

# Create the mytool user and grant the required permissions.
mysql --execute="CREATE USER mytool@localhost IDENTIFIED BY 'aComplex1'"
mysql --execute="GRANT ALL ON *.* TO mytool@localhost"

#!/bin/bash -eux

retry() {
  local COUNT=1
  local RESULT=0
  while [[ "${COUNT}" -le 10 ]]; do
    [[ "${RESULT}" -ne 0 ]] && {
      [ "`which tput 2> /dev/null`" != "" ] && tput setaf 1
      echo -e "\\n${*} failed... retrying ${COUNT} of 10.\\n" >&2
      [ "`which tput 2> /dev/null`" != "" ] && tput sgr0
    }
    "${@}" && { RESULT=0 && break; } || RESULT="${?}"
    COUNT="$((COUNT + 1))"

    # Increase the delay with each iteration.
    DELAY="$((DELAY + 10))"
    sleep $DELAY
  done

  [[ "${COUNT}" -gt 10 ]] && {
    [ "`which tput 2> /dev/null`" != "" ] && tput setaf 1
    echo -e "\\nThe command failed 10 times.\\n" >&2
    [ "`which tput 2> /dev/null`" != "" ] && tput sgr0
  }

  return "${RESULT}"
}

# The mysql client and related utilities.
retry apk add mariadb mariadb-client mariadb-common libaio libgcc libstdc++

# Delete these lines, if they exist, and explicitly configure the data directory.
sed -i "/datadir/d" /etc/mysql/my.cnf
sed -i "/innodb_data_home_dir/d" /etc/mysql/my.cnf
sed -i '/\[mysqld\].*/a \datadir\=\/var\/lib\/mysql\/\ninnodb_data_home_dir\=\/var\/lib\/mysql\/\n\end' /etc/mysql/my.cnf

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

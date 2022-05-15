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
retry yum install --assumeyes mariadb mariadb-libs mariadb-server perl-DBI perl-DBD-MySQL

# OpenSSL command line tool is used to generate a password below.
retry yum install --assumeyes openssl

# Change the default temporary table directory or else the schema reset will fail when it creates a temp table.
printf "\n\n[server]\ntmpdir=/tmp/\n\n" >> /etc/my.cnf.d/server-tmpdir.cnf
chcon system_u:object_r:mysqld_etc_t:s0 /etc/my.cnf.d/server-tmpdir.cnf

printf "[mysqld]" >> /etc/my.cnf.d/server-buffers.cnf
printf "back_log = 1500" >> /etc/my.cnf.d/server-buffers.cnf
printf "table_open_cache = 520" >> /etc/my.cnf.d/server-buffers.cnf
printf "key_buffer_size = 16M" >> /etc/my.cnf.d/server-buffers.cnf
printf "query_cache_type = 0" >> /etc/my.cnf.d/server-buffers.cnf
printf "join_buffer_size = 32K" >> /etc/my.cnf.d/server-buffers.cnf
printf "sort_buffer_size = 32K" >> /etc/my.cnf.d/server-buffers.cnf
printf "innodb_buffer_pool_size=128M" >> /etc/my.cnf.d/server-buffers.cnf
printf "innodb_use_native_aio=1" >> /etc/my.cnf.d/server-buffers.cnf
printf "innodb_data_file_path=ibdata1:50M:autoextend" >> /etc/my.cnf.d/server-buffers.cnf
printf "innodb_file_per_table=1" >> /etc/my.cnf.d/server-buffers.cnf
printf "innodb_open_files=100" >> /etc/my.cnf.d/server-buffers.cnf
printf "innodb_flush_log_at_trx_commit=1" >> /etc/my.cnf.d/server-buffers.cnf
printf "innodb_lock_wait_timeout = 120" >> /etc/my.cnf.d/server-buffers.cnf
printf "innodb_doublewrite=0" >> /etc/my.cnf.d/server-buffers.cnf
printf "innodb_buffer_pool_instances=16" >> /etc/my.cnf.d/server-buffers.cnf
printf "max-prepared-stmt-count=400000" >> /etc/my.cnf.d/server-buffers.cnf
printf "innodb_fast_shutdown=0" >> /etc/my.cnf.d/server-buffers.cnf
printf "innodb_log_buffer_size=128M" >> /etc/my.cnf.d/server-buffers.cnf
printf "innodb_log_files_in_group=3" >> /etc/my.cnf.d/server-buffers.cnf
printf "innodb_log_file_size=128M" >> /etc/my.cnf.d/server-buffers.cnf
printf "innodb_thread_concurrency=32" >> /etc/my.cnf.d/server-buffers.cnf
printf "innodb_flush_method = O_DIRECT" >> /etc/my.cnf.d/server-buffers.cnf
printf "innodb_write_io_threads=16" >> /etc/my.cnf.d/server-buffers.cnf
printf "innodb_read_io_threads=16" >> /etc/my.cnf.d/server-buffers.cnf
printf "innodb_max_dirty_pages_pct=10" >> /etc/my.cnf.d/server-buffers.cnf
printf "skip-name-resolve" >> /etc/my.cnf.d/server-buffers.cnf
printf "innodb_adaptive_flushing=1" >> /etc/my.cnf.d/server-buffers.cnf
printf "innodb_file_format=barracuda" >> /etc/my.cnf.d/server-buffers.cnf
printf "innodb_fast_shutdown=0" >> /etc/my.cnf.d/server-buffers.cnf
printf "innodb_io_capacity=25000" >> /etc/my.cnf.d/server-buffers.cnf
chcon system_u:object_r:mysqld_etc_t:s0 /etc/my.cnf.d/server-buffers.cnf

# Enable and start the daemons.
systemctl enable mariadb
systemctl start mariadb

# Setup the mysql root account with a random password.
export PRAND=`openssl rand -base64 18`
mysqladmin --user=root password "$PRAND"

# Allow the root user to login to mysql as root by saving the randomly generated password.
printf "\n\n[mysql]\nuser=root\npassword=$PRAND\n\n" >> /root/.my.cnf

# Create the mytool user and grant the required permissions.
mysql --execute="CREATE USER mytool@localhost IDENTIFIED BY 'aComplex1'"
mysql --execute="GRANT ALL ON *.* TO mytool@localhost"

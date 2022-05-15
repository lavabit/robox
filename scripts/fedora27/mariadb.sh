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
retry dnf install --assumeyes libevent memcached mariadb mariadb-libs mariadb-server perl-DBI perl-DBD-MySQL

# OpenSSL command line tool is used to generate a password below.
retry dnf install --assumeyes openssl

# Change the default temporary table directory or else the schema reset will fail when it creates a temp table.
printf "\n\n[server]\ntmpdir=/tmp/\n\n" >> /etc/my.cnf.d/server-tmpdir.cnf
chcon system_u:object_r:mysqld_etc_t:s0 /etc/my.cnf.d/server-tmpdir.cnf

printf "[mysqld]\n" >> /etc/my.cnf.d/server-buffers.cnf
printf "back_log = 1500\n" >> /etc/my.cnf.d/server-buffers.cnf
printf "table_open_cache = 520\n" >> /etc/my.cnf.d/server-buffers.cnf
printf "table_open_cache_instances = 32\n" >> /etc/my.cnf.d/server-buffers.cnf
printf "key_buffer_size = 16M\n" >> /etc/my.cnf.d/server-buffers.cnf
printf "query_cache_type = 0\n" >> /etc/my.cnf.d/server-buffers.cnf
printf "join_buffer_size = 32K\n" >> /etc/my.cnf.d/server-buffers.cnf
printf "sort_buffer_size = 32K\n" >> /etc/my.cnf.d/server-buffers.cnf
printf "innodb_buffer_pool_size=128M\n" >> /etc/my.cnf.d/server-buffers.cnf
printf "innodb_use_native_aio=1\n" >> /etc/my.cnf.d/server-buffers.cnf
printf "innodb_data_file_path=ibdata1:50M:autoextend\n" >> /etc/my.cnf.d/server-buffers.cnf
printf "innodb_file_per_table=1\n" >> /etc/my.cnf.d/server-buffers.cnf
printf "innodb_open_files=100\n" >> /etc/my.cnf.d/server-buffers.cnf
printf "innodb_flush_log_at_trx_commit=1\n" >> /etc/my.cnf.d/server-buffers.cnf
printf "innodb_lock_wait_timeout = 120\n" >> /etc/my.cnf.d/server-buffers.cnf
printf "innodb_doublewrite=0\n" >> /etc/my.cnf.d/server-buffers.cnf
printf "innodb_buffer_pool_instances=16\n" >> /etc/my.cnf.d/server-buffers.cnf
printf "innodb_mtflush_threads=16\n" >> /etc/my.cnf.d/server-buffers.cnf
printf "innodb_compression_level=6\n" >> /etc/my.cnf.d/server-buffers.cnf
printf "innodb_compression_algorithm=zlib\n" >> /etc/my.cnf.d/server-buffers.cnf
printf "max-prepared-stmt-count=400000\n" >> /etc/my.cnf.d/server-buffers.cnf
printf "innodb_fast_shutdown=0\n" >> /etc/my.cnf.d/server-buffers.cnf
printf "innodb_log_buffer_size=128M\n" >> /etc/my.cnf.d/server-buffers.cnf
printf "innodb_log_files_in_group=3\n" >> /etc/my.cnf.d/server-buffers.cnf
printf "innodb_log_file_size=128M\n" >> /etc/my.cnf.d/server-buffers.cnf
printf "innodb_thread_concurrency=32\n" >> /etc/my.cnf.d/server-buffers.cnf
printf "innodb_flush_method = O_DIRECT\n" >> /etc/my.cnf.d/server-buffers.cnf
printf "innodb_write_io_threads=16\n" >> /etc/my.cnf.d/server-buffers.cnf
printf "innodb_read_io_threads=16\n" >> /etc/my.cnf.d/server-buffers.cnf
printf "innodb_max_dirty_pages_pct=10\n" >> /etc/my.cnf.d/server-buffers.cnf
printf "skip-name-resolve\n" >> /etc/my.cnf.d/server-buffers.cnf
printf "innodb_adaptive_flushing=1\n" >> /etc/my.cnf.d/server-buffers.cnf
printf "innodb_file_format=barracuda\n" >> /etc/my.cnf.d/server-buffers.cnf
printf "innodb_fast_shutdown=0\n" >> /etc/my.cnf.d/server-buffers.cnf
printf "innodb_mtflush_threads=16\n" >> /etc/my.cnf.d/server-buffers.cnf
printf "innodb_use_mtflush=1\n" >> /etc/my.cnf.d/server-buffers.cnf
printf "innodb_checksum_algorithm=crc32\n" >> /etc/my.cnf.d/server-buffers.cnf
printf "innodb_flush_neighbors=0\n" >> /etc/my.cnf.d/server-buffers.cnf
printf "innodb_lru_scan_depth=2500 \n" >> /etc/my.cnf.d/server-buffers.cnf
printf "innodb_io_capacity=25000\n" >> /etc/my.cnf.d/server-buffers.cnf
printf "innodb_io_capacity_max=35000\n" >> /etc/my.cnf.d/server-buffers.cnf
chcon system_u:object_r:mysqld_etc_t:s0 /etc/my.cnf.d/server-buffers.cnf

# Enable and start the daemons.
systemctl enable mariadb
systemctl start mariadb

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

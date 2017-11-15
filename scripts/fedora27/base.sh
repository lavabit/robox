#!/bin/bash

# Ensure a nameserver is being used that won't return an IP for non-existent domain names.
printf "\nnameserver 4.2.2.1\n" > /etc/resolv.conf

# Set the local hostname to resolve properly.
printf "\n127.0.0.1	magma.builder\n\n" >> /etc/hosts

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
printf "skip-grant-tables\n" >> /etc/my.cnf.d/server-buffers.cnf
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
printf "innodb_compression_algorithm=2\n" >> /etc/my.cnf.d/server-buffers.cnf
printf "max-prepared-stmt-count=400000\n" >> /etc/my.cnf.d/server-buffers.cnf
printf "innodb_fast_shutdown=0\n" >> /etc/my.cnf.d/server-buffers.cnf
printf "innodb_log_buffer_size=256M\n" >> /etc/my.cnf.d/server-buffers.cnf
printf "innodb_log_files_in_group=3\n" >> /etc/my.cnf.d/server-buffers.cnf
printf "innodb_log_file_size=8G\n" >> /etc/my.cnf.d/server-buffers.cnf
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
systemctl enable haveged
systemctl enable memcached
systemctl start mariadb
systemctl start haveged
systemctl start memcached

# Disable IPv6 and the iptables module used to firewall IPv6.
printf "\n\nnet.ipv6.conf.all.disable_ipv6 = 1\n" >> /etc/sysctl.conf

sed -i -e "s/IPV6INIT=yes/IPV6INIT=no/g" /etc/sysconfig/network-scripts/ifcfg-eth0
sed -i -e "s/IPV6_AUTOCONF=yes/IPV6_AUTOCONF=no/g" /etc/sysconfig/network-scripts/ifcfg-eth0
sed -i -e "s/IPV6_DEFROUTE=yes/IPV6_DEFROUTE=no/g" /etc/sysconfig/network-scripts/ifcfg-eth0
sed -i -e "s/IPV6_PEERDNS=yes/IPV6_PEERDNS=no/g" /etc/sysconfig/network-scripts/ifcfg-eth0
sed -i -e "s/IPV6_PEERROUTES=yes/IPV6_PEERROUTES=no/g" /etc/sysconfig/network-scripts/ifcfg-eth0

# Close a potential security hole.
systemctl disable remote-fs.target

# Disable kernel dumping.
# systemctl disable kdump.service

# Cleanup the rpmnew file.
# mv --force /etc/nsswitch.conf.rpmnew /etc/nsswitch.conf

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

# Reboot
shutdown --reboot --no-wall +1

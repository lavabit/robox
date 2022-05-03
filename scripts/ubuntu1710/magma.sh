#!/bin/bash -eux

retry() {
  local COUNT=1
  local DELAY=0
  local RESULT=0
  while [[ "${COUNT}" -le 10 ]]; do
    [[ "${RESULT}" -ne 0 ]] && {
      [ "`which tput 2> /dev/null`" != "" ] && [ -n "$TERM" ] && tput setaf 1
      echo -e "\\n${*} failed... retrying ${COUNT} of 10.\\n" >&2
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
    echo -e "\\nThe command failed 10 times.\\n" >&2
    [ "`which tput 2> /dev/null`" != "" ] && [ -n "$TERM" ] && tput sgr0
  }

  return "${RESULT}"
}

# To allow for automated installs, we disable interactive configuration steps.
export DEBIAN_FRONTEND=noninteractive
export DEBCONF_NONINTERACTIVE_SEEN=true

# The packages needed to compile Magma.
retry apt-get --assume-yes install perl cmake gcc g++ gcc-multilib pkg-config libbsd-dev make autoconf autoconf-archive automake libtool flex bison gdb valgrind valgrind-dbg m4 python-pytest nasm libdigest-bcrypt-perl libdigest-crc-perl libdigest-hmac-perl libdigest-jhash-perl libdigest-md2-perl libdigest-md4-perl libdigest-sha-perl libdigest-sha3-perl libdigest-whirlpool-perl gnu-standards gettext

# Need to retrieve the source code.
retry apt-get --assume-yes install git git-man liberror-perl rsync wget

# Needed to run the watcher and status scripts.
retry apt-get --assume-yes install sysstat inotify-tools

# Needed to run the stacie script.
retry apt-get --assume-yes install python-crypto python-cryptography

# Make sure the MySQLs server is available.
retry apt-get --assume-yes install mysql-server

# Install ClamAV.
retry apt-get --assume-yes install clamav clamav-daemon clamav-freshclam 
systemctl --quiet is-enabled clamav-freshclam.service &> /dev/null && \
  ( systemctl stop clamav-freshclam.service &> /dev/null ;
  systemctl disable clamav-freshclam.service &> /dev/null ) || \
  echo "clamav-freshclam.service already disabled" &> /dev/null

# On Debian/Ubuntu there is no virus database package. We use freshclam instead.
( cd /var/lib/clamav && rm -f main.cvd daily.cvd bytecode.cvd && \
  curl -LSOs https://github.com/ladar/clamav-data/raw/main/main.cvd.[01-10] \
  -LSOs https://github.com/ladar/clamav-data/raw/main/main.cvd.sha256 \
  -LSOs https://github.com/ladar/clamav-data/raw/main/daily.cvd.[01-10] \
  -LSOs https://github.com/ladar/clamav-data/raw/main/daily.cvd.sha256 \
  -LSOs https://github.com/ladar/clamav-data/raw/main/bytecode.cvd \
  -LSOs https://github.com/ladar/clamav-data/raw/main/bytecode.cvd.sha256 && \
  cat main.cvd.01 main.cvd.02 main.cvd.03 main.cvd.04 main.cvd.05 \
  main.cvd.06 main.cvd.07 main.cvd.08 main.cvd.09 main.cvd.10 > main.cvd && \
  cat daily.cvd.01 daily.cvd.02 daily.cvd.03 daily.cvd.04 daily.cvd.05 \
  daily.cvd.06 daily.cvd.07 daily.cvd.08 daily.cvd.09 daily.cvd.10 > daily.cvd && \
  sha256sum -c main.cvd.sha256 daily.cvd.sha256 bytecode.cvd.sha256 || exit 1 ; \
  rm -f main.cvd.[01-10] daily.cvd.[01-10] main.cvd.sha256 daily.cvd.sha256 bytecode.cvd.sha256 && \
  cd $HOME/ )
  
freshclam --quiet || \
  echo "The freshclam attempt failed ... ignoring." &> /dev/null

# Force MySQL/MariaDB except the old fashioned '0000-00-00' date format.
if [ -d /etc/mysql/mysql.conf.d/ ]; then
  printf "[mysqld]\nsql-mode=allow_invalid_dates\n" >> /etc/mysql/mysql.conf.d/server-mode.cnf
fi

if [ -d /etc/mysql/mariadb.conf.d/ ]; then
  printf "[mysqld]\nsql-mode=allow_invalid_dates\n" >> /etc/mysql/mariadb.conf.d/server-mode.cnf
fi

# Create the mytool user and grant the required permissions.
mysql --execute="CREATE USER mytool@localhost IDENTIFIED BY 'aComplex1'"
mysql --execute="GRANT ALL ON *.* TO mytool@localhost"

# The postfix server for message relays.
retry apt-get --assume-yes install postfix

# Configure the postfix hostname and origin parameters.
printf "\ninet_interfaces = localhost\n" >> /etc/postfix/main.cf
printf "inet_protocols = ipv4\n" >> /etc/postfix/main.cf
printf "myhostname = relay.magma.builder\n" >> /etc/postfix/main.cf
printf "myorigin = magma.builder\n" >> /etc/postfix/main.cf
printf "transport_maps = hash:/etc/postfix/transport\n" >> /etc/postfix/main.cf

# Configure postfix to listen for relays on port 2525 so it doesn't conflict with magma.
sed -i -e "s/^smtp\([ ]*inet\)/127.0.0.1:2525\1/" /etc/postfix/master.cf

printf "\nmagma.builder         smtp:[127.0.0.1]:7000\n" >> /etc/postfix/transport
printf "magmadaemon.com         smtp:[127.0.0.1]:7000\n" >> /etc/postfix/transport
postmap /etc/postfix/transport

# Setup the the box. This runs as root
if [ -d /home/vagrant/ ]; then
  OUTPUT="/home/vagrant/magma-build.sh"
else
  OUTPUT="/root/magma-build.sh"
fi

# Grab a snapshot of the development branch.
cat <<-EOF > $OUTPUT
#!/bin/bash

error() {
  if [ \$? -ne 0 ]; then
    printf "Compilation of the bundled Magma dependencies failed.\n\n";
    exit 1
  fi
}

if [ -x /usr/bin/id ]; then
  ID=\`/usr/bin/id -u\`
  if [ -n "\$ID" -a "\$ID" -eq 0 ]; then
    systemctl start mariadb.service
    systemctl start postfix.service
    systemctl start memcached.service
  fi
fi

# If the TERM environment variable is missing, then tput may trigger a fatal error.
if [[ -n "\$TERM" ]] && [[ "\$TERM" -ne "dumb" ]]; then
  export TPUT="tput"
else
  export TPUT="tput -Tvt100"
fi

# We need to give the box 30 seconds to get the networking setup or
# the git clone operation will fail.
sleep 30

# Temporary [hopefully] workaround to avoid [yet another] bug in NSS.
export NSS_DISABLE_HW_AES=1

# If the directory is present, remove it so we can clone a fresh copy.
if [ -d magma-develop ]; then
  rm --recursive --force magma-develop
fi

# Use the GitHub repository to clone the Magma source code.
git clone --quiet https://github.com/lavabit/magma.git magma-develop && \
  printf "\nMagma repository downloaded.\n" ; error
cd magma-develop; error

# Setup the bin links, just in case we need to troubleshoot something manually.
dev/scripts/linkup.sh; error

# Explicitly control the number of build jobs (instead of using nproc).
[ ! -z "\${MAGMA_JOBS##*[!0-9]*}" ] && export M_JOBS="\$MAGMA_JOBS"

# The unit tests for the bundled dependencies get skipped with quick builds.
MAGMA_QUICK=\$(echo \$MAGMA_QUICK | tr "[:lower:]" "[:upper:]")
if [ "\$MAGMA_QUICK" == "YES" ]; then
  export QUICK=yes
fi

# Compile the dependencies into a shared library.
dev/scripts/builders/build.lib.sh all; error

# Reset the sandbox database and storage files.
dev/scripts/database/schema.reset.sh &> lib/logs/schema.txt && \
  printf "The Magma database schema installed successfully.\n"; error

# Controls whether ClamAV is enabled, and/or if the signature databases get updated.
MAGMA_CLAMAV=\$(echo \$MAGMA_CLAMAV | tr "[:lower:]" "[:upper:]")
MAGMA_CLAMAV_FRESHEN=\$(echo \$MAGMA_CLAMAV_FRESHEN | tr "[:lower:]" "[:upper:]")
MAGMA_CLAMAV_DOWNLOAD=\$(echo \$MAGMA_CLAMAV_DOWNLOAD | tr "[:lower:]" "[:upper:]")
if [ "\$MAGMA_CLAMAV" == "YES" ]; then
  sed -i 's/^[# ]*magma.iface.virus.available[ ]*=.*$/magma.iface.virus.available = true/g' sandbox/etc/magma.sandbox.config
  ( cp /var/lib/clamav/bytecode.cvd sandbox/virus/ && \
  cp /var/lib/clamav/daily.cvd sandbox/virus/ && \
  cp /var/lib/clamav/main.cvd sandbox/virus/ ) || \
  printf "Unable to setup the system copy of the virus databases.\n" \
    "A download, or freshen must succeed, or the anti-virus unit tests will fail.\n"
else
  sed -i 's/^[# ]*magma.iface.virus.available[ ]*=.*$/magma.iface.virus.available = false/g' sandbox/etc/magma.sandbox.config
fi
if [ "\$MAGMA_CLAMAV_DOWNLOAD" == "YES" ]; then
  ( cd sandbox/virus/ && rm -f main.cvd* daily.cvd* bytecode.cvd* && \
  curl -LSOs https://github.com/ladar/clamav-data/raw/main/main.cvd.[01-10] \
  -LSOs https://github.com/ladar/clamav-data/raw/main/main.cvd.sha256 \
  -LSOs https://github.com/ladar/clamav-data/raw/main/daily.cvd.[01-10] \
  -LSOs https://github.com/ladar/clamav-data/raw/main/daily.cvd.sha256 \
  -LSOs https://github.com/ladar/clamav-data/raw/main/bytecode.cvd \
  -LSOs https://github.com/ladar/clamav-data/raw/main/bytecode.cvd.sha256 && \
  cat main.cvd.01 main.cvd.02 main.cvd.03 main.cvd.04 main.cvd.05 \
  main.cvd.06 main.cvd.07 main.cvd.08 main.cvd.09 main.cvd.10 > main.cvd && \
  cat daily.cvd.01 daily.cvd.02 daily.cvd.03 daily.cvd.04 daily.cvd.05 \
  daily.cvd.06 daily.cvd.07 daily.cvd.08 daily.cvd.09 daily.cvd.10 > daily.cvd && \
  sha256sum -c main.cvd.sha256 daily.cvd.sha256 bytecode.cvd.sha256 || \
  { printf "The ClamAV database download failed. Ignoring.\n" ; ls -alh * ; }
  
  rm -f main.cvd.sha256 daily.cvd.sha256 bytecode.cvd.sha256 main.cvd.[01-10] daily.cvd.[01-10]
  cd \$HOME/magma-develop )
fi
if [ "\$MAGMA_CLAMAV_FRESHEN" == "YES" ]; then
  dev/scripts/freshen/freshen.clamav.sh &> lib/logs/freshen.txt && \
    printf "The ClamAV databases have been updated.\n"; error
fi

# Ensure the sandbox config uses port 2525 for relays.
sed -i -e "/magma.relay\[[0-9]*\].name.*/d" sandbox/etc/magma.sandbox.config
sed -i -e "/magma.relay\[[0-9]*\].port.*/d" sandbox/etc/magma.sandbox.config
sed -i -e "/magma.relay\[[0-9]*\].secure.*/d" sandbox/etc/magma.sandbox.config
printf "\n\nmagma.relay[1].name = localhost\nmagma.relay[1].port = 2525\n\n" >> sandbox/etc/magma.sandbox.config

# Bug fix... create the scan directory so ClamAV unit tests work.
if [ ! -d 'sandbox/spool/scan/' ]; then
  mkdir -p sandbox/spool/scan/
fi

# Compile the daemon and then compile the unit tests.
make -j4 all &> lib/logs/magma.txt && \
  printf "The Magma code compiled successfully.\n\n"; error

# Change the socket path.
sed -i -e "s/\/var\/lib\/mysql\/mysql.sock/\/var\/run\/mysqld\/mysqld.sock/g" sandbox/etc/magma.sandbox.config

# Run the unit tests and capture the return code, if they fail, print an error, 
# and then exit using the captured return code.
dev/scripts/launch/check.run.sh
RETVAL=\$?
if [ \$RETVAL -ne 0 ]; then
  \${TPUT} setaf 1; \${TPUT} bold; printf "Some of the Magma unit tests failed...\n\n"; \${TPUT} sgr0;
  exit \$RETVAL
fi

# Additionally, run the unit tests atop Valgrind, note this will take a 
# long time if the anti-virus engine is enabled, but like the normal unit
# tests above, we capture the return code. If they fail, print an error, 
# and then exit using the captured return code.
MAGMA_MEMCHECK=\$(echo \$MAGMA_MEMCHECK | tr "[:lower:]" "[:upper:]")
if [ "\$MAGMA_MEMCHECK" == "YES" ]; then
  dev/scripts/launch/check.vg.sh
  RETVAL=\$?
  if [ \$RETVAL -ne 0 ]; then
    \${TPUT} setaf 1; \${TPUT} bold; printf "Some of the Magma unit tests failed...\n\n"; \${TPUT} sgr0;
    exit \$RETVAL
  fi
fi

# Uncomment the follwoing lines to have Magma daemonize instead of running in the foreground.
# sed -i -e "s/magma.output.file = false/magma.output.file = true/g" sandbox/etc/magma.sandbox.config
# sed -i -e "s/magma.system.daemonize = false/magma.system.daemonize = true/g" sandbox/etc/magma.sandbox.config

# Launch the daemon, and give it time to start before exiting.
# ./magmad --config magma.system.daemonize=true sandbox/etc/magma.sandbox.config  || exit 1
# sleep 15

# Ensure we exit with a zero so Vagrant and/or the various CI systems used 
# for testing know everything worked.
exit 0
EOF

# Make the script executable.
if [ -d /home/vagrant/ ]; then
  chown vagrant:vagrant /home/vagrant/magma-build.sh
  chmod +x /home/vagrant/magma-build.sh
else
  chmod +x /root/magma-build.sh
fi

# Customize the message of the day
printf "Magma Daemon Development Environment\nTo download and compile magma, just execute the magma-build.sh script.\n\n" > /etc/motd

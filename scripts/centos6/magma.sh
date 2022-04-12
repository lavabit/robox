#!/bin/bash -eux

retry() {
  local COUNT=1
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

# Install the the EPEL repository.
retry yum --assumeyes --enablerepo=extras install epel-release

# Packages needed beyond a minimal install to build and run magma.
retry yum --assumeyes install valgrind valgrind-devel texinfo autoconf automake libtool ncurses-devel gcc-c++ libstdc++-devel gcc cloog-ppl cpp glibc-devel glibc-headers kernel-headers libgomp mpfr ppl perl perl-Module-Pluggable perl-Pod-Escapes perl-Pod-Simple perl-libs perl-version patch sysstat perl-Time-HiRes cmake libarchive 

# Install libbsd because DSPAM relies upon for the strl functions, and the
# entropy which improves the availability of random bits, and helps magma
# launch and complete her unit tests faster.
retry yum --assumeyes install libbsd libbsd-devel inotify-tools haveged

# The MySQL services magma relies upon.
retry yum --assumeyes install mysql mysql-server perl-DBI perl-DBD-MySQL

# The memcached services magma uses.
retry yum --assumeyes install libevent memcached

# Packages used to retrieve the magma code, but aren't required for building/running the daemon.
retry yum --assumeyes install wget git rsync perl-Git perl-Error

# Install ClamAV.
retry yum --assumeyes install clamav clamav-data

# Ensure memcached doesn't try to use IPv6.
if [ -f /etc/sysconfig/memcached ]; then
  sed -i "s/[,]\?\:\:1[,]\?//g" /etc/sysconfig/memcached
fi

# Enable and start the daemons.
chkconfig mysqld on
chkconfig memcached on
service mysqld start
service memcached start

# Setup the mysql root account with a random password.
export PRAND=`openssl rand -base64 18`
mysqladmin --user=root password "$PRAND"

# Allow the root user to login to mysql as root by saving the randomly generated password.
printf "\n\n[mysql]\nuser=root\npassword=$PRAND\n\n" >> /root/.my.cnf

# Create the mytool user and grant the required permissions.
mysql --execute="CREATE USER mytool@localhost IDENTIFIED BY 'aComplex1'"
mysql --execute="GRANT ALL ON *.* TO mytool@localhost"

# Install the python packages needed for the stacie script to run, which requires the python cryptography package (installed via pip).
retry yum --assumeyes install zlib-devel openssl-devel libffi-devel python-pip python-ply python-devel python-pycparser python-crypto2.6 libcom_err-devel libsepol-devel libselinux-devel keyutils-libs-devel krb5-devel

# Install the Python Prerequisites
pip install --disable-pip-version-check cryptography==1.5.2 cffi==1.11.5 enum34==1.1.6 idna==2.7 ipaddress==1.0.22 pyasn1==0.4.4 six==1.11.0 setuptools==11.3

printf "export PYTHONPATH=/usr/lib64/python2.6/site-packages/pycrypto-2.6.1-py2.6-linux-x86_64.egg/\n" > /etc/profile.d/pypath.sh
chcon "system_u:object_r:bin_t:s0" /etc/profile.d/pypath.sh
chmod 644 /etc/profile.d/pypath.sh

cat <<-EOF > /etc/security/limits.d/25-root.conf
root    soft    memlock    2027044
root    hard    memlock    2027044
root    soft    stack      2027044
root    hard    stack      2027044
root    soft    nofile     1048576
root    hard    nofile     1048576
root    soft    nproc      65536
root    hard    nproc      65536
EOF

cat <<-EOF > /etc/security/limits.d/90-everybody.conf
*    soft    memlock    2027044
*    hard    memlock    2027044
*    soft    stack      unlimited
*    hard    stack      unlimited
*    soft    nofile     65536
*    hard    nofile     65536
*    soft    nproc      65536
*    hard    nproc      65536
EOF

chmod 644 /etc/security/limits.d/25-root.conf
chmod 644 /etc/security/limits.d/90-everybody.conf
chcon "system_u:object_r:etc_t:s0" /etc/security/limits.d/25-root.conf
chcon "system_u:object_r:etc_t:s0" /etc/security/limits.d/90-everybody.conf

# Create the clamav user to avoid spurious errors when compilintg ClamAV.
useradd clamav && usermod --lock --shell /sbin/nologin clamav

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
    printf "\n\nmagma daemon compilation failed...\n\n";
    exit 1
  fi
}

if [ -x /usr/bin/id ]; then
  ID=\`/usr/bin/id -u\`
  if [ -n "\$ID" -a "\$ID" -eq 0 ]; then
    service mysqld start
    service postfix start
    service memcached start
  fi
fi

# If the TERM environment variable is missing, then tput may trigger a fatal error.
if [[ -n "$TERM" ]] && [[ "$TERM" -ne "dumb" ]]; then
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

# Clone the magma repository off Github.
git clone https://github.com/lavabit/magma.git magma-develop; error
cd magma-develop; error

# Setup the bin links, just in case we need to troubleshoot things manually.
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
dev/scripts/database/schema.reset.sh; error

# Controls whether ClamAV is enabled, and/or if the signature databases get updated.
MAGMA_CLAMAV=\$(echo \$MAGMA_CLAMAV | tr "[:lower:]" "[:upper:]")
MAGMA_CLAMAV_FRESHEN=\$(echo \$MAGMA_CLAMAV_FRESHEN | tr "[:lower:]" "[:upper:]")
MAGMA_CLAMAV_DOWNLOAD=\$(echo \$MAGMA_CLAMAV_DOWNLOAD | tr "[:lower:]" "[:upper:]")
( cp /var/lib/clamav/bytecode.cvd sandbox/virus/ && cp /var/lib/clamav/daily.cvd sandbox/virus/ && cp /var/lib/clamav/main.cvd sandbox/virus/ ) || echo "Unable to use the system copy of the virus databases."
if [ "\$MAGMA_CLAMAV" == "YES" ]; then
  sed -i -e "s/virus.available = false/virus.available = true/g" sandbox/etc/magma.sandbox.config
fi
if [ "\$MAGMA_CLAMAV_DOWNLOAD" == "YES" ]; then
  cd sandbox/virus/ && curl -LOs \
  https://github.com/ladar/clamav-data/raw/main/main.cvd.[01-10] -LOs \
  https://github.com/ladar/clamav-data/raw/main/main.cvd.sha256 -LOs \
  https://github.com/ladar/clamav-data/raw/main/daily.cvd.[01-10] -LOs \
  https://github.com/ladar/clamav-data/raw/main/daily.cvd.sha256 -LOs \
  https://github.com/ladar/clamav-data/raw/main/bytecode.cvd -LOs \
  https://github.com/ladar/clamav-data/raw/main/bytecode.cvd.sha256 && \
  rm -f main.cvd daily.cvd bytecode.cvd && \
  cat main.cvd.01 main.cvd.02 main.cvd.03 main.cvd.04 main.cvd.05 \
  main.cvd.06 main.cvd.07 main.cvd.08 main.cvd.09 main.cvd.10 > main.cvd && \
  cat daily.cvd.01 daily.cvd.02 daily.cvd.03 daily.cvd.04 daily.cvd.05 \
  daily.cvd.06 daily.cvd.07 daily.cvd.08 daily.cvd.09 daily.cvd.10 > daily.cvd && \
  sha256sum -c main.cvd.sha256 daily.cvd.sha256 bytecode.cvd.sha256 && \
  rm -f main.cvd.[01-10] daily.cvd.[01-10] && \
  cd \$HOME/magma-develop
fi
if [ "\$MAGMA_CLAMAV_FRESHEN" == "YES" ]; then
  dev/scripts/freshen/freshen.clamav.sh 2>&1 | grep -v WARNING | grep -v PANIC; error
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
make all; error

# Run the unit tests.
dev/scripts/launch/check.run.sh

# If the unit tests fail, print an error, but contine running.
if [ \$? -ne 0 ]; then
  \${TPUT} setaf 1; \${TPUT} bold; printf "\n\nsome of the magma daemon unit tests failed...\n\n"; \${TPUT} sgr0;
  for i in 1 2 3; do
    printf "\a"; sleep 1
  done
  sleep 12
fi

# Alternatively, run the unit tests atop Valgrind.
# Note this takes awhile when the anti-virus engine is enabled.
MAGMA_MEMCHECK=\$(echo \$MAGMA_MEMCHECK | tr "[:lower:]" "[:upper:]")
if [ "\$MAGMA_MEMCHECK" == "YES" ]; then
  dev/scripts/launch/check.vg
fi

# Daemonize instead of running on the console.
sed -i -e "s/magma.output.file = false/magma.output.file = true/g" sandbox/etc/magma.sandbox.config

# Launch the daemon.
# ./magmad --config magma.system.daemonize=true sandbox/etc/magma.sandbox.config

# Save the result.
# RETVAL=\$?

# Give the daemon time to start before exiting.
sleep 15

# Exit wit a zero so Vagrant doesn't think a failed unit test is a provision failure.
exit \$RETVAL
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

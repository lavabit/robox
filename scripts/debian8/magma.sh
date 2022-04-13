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

# To allow for automated installs, we disable interactive configuration steps.
export DEBIAN_FRONTEND=noninteractive
export DEBCONF_NONINTERACTIVE_SEEN=true

# Install the missing dependencies used to compile magma.
retry apt-get --assume-yes install cmake mariadb-server

# Install the SQL server.
retry apt-get --assume-yes install mariadb-server

# Force MySQL/MariaDB except the old fashioned '0000-00-00' date format.
printf "[mysqld]\nsql-mode=allow_invalid_dates\n" >> /etc/mysql/conf.d//60-server-mode.cnf

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
    systemctl start mysql.service
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

# Clone the magma repository off Github.
git clone --quiet https://github.com/lavabit/magma.git magma-develop && \
  printf "\nMagma repository downloaded.\n" ; error
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
dev/scripts/database/schema.reset.sh &> lib/logs/schema.txt && \
  printf "\nMagma database schema loaded successfully.\n"; error

# Controls whether ClamAV is enabled, and/or if the signature databases get updated.
MAGMA_CLAMAV=\$(echo \$MAGMA_CLAMAV | tr "[:lower:]" "[:upper:]")
MAGMA_CLAMAV_FRESHEN=\$(echo \$MAGMA_CLAMAV_FRESHEN | tr "[:lower:]" "[:upper:]")
MAGMA_CLAMAV_DOWNLOAD=\$(echo \$MAGMA_CLAMAV_DOWNLOAD | tr "[:lower:]" "[:upper:]")
if [ "\$MAGMA_CLAMAV" == "YES" ]; then
  sed -i 's/^[# ]*magma.iface.virus.available[ ]*=.*$/magma.iface.virus.available = true/g' sandbox/etc/magma.sandbox.config
else
  sed -i 's/^[# ]*magma.iface.virus.available[ ]*=.*$/magma.iface.virus.available = false/g' sandbox/etc/magma.sandbox.config
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
  dev/scripts/freshen/freshen.clamav.sh &> lib/logs/freshen.txt && \
    printf "\nClamAV databases updated.\n"; error
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
  printf "\nMagma compiled successfully.\n"; error

# Change the socket path.
sed -i -e "s/\/var\/lib\/mysql\/mysql.sock/\/var\/run\/mysqld\/mysqld.sock/g" sandbox/etc/magma.sandbox.config

# Run the unit tests.
dev/scripts/launch/check.run.sh

# If the unit tests fail, print an error, but contine running.
if [ \$? -ne 0 ]; then
  \${TPUT} setaf 1; \${TPUT} bold; printf "\n\nSome of the magma unit tests failed...\n\n"; \${TPUT} sgr0;
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
# sed -i -e "s/magma.output.file = false/magma.output.file = true/g" sandbox/etc/magma.sandbox.config
# sed -i -e "s/magma.system.daemonize = false/magma.system.daemonize = true/g" sandbox/etc/magma.sandbox.config

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

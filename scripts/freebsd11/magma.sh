#!/bin/bash -eux
#
# Setup the the box. This runs as root

# Configure fetch so it retries temporary failures.
export FETCH_RETRY=5
export FETCH_TIMEOUT=30
export ASSUME_ALWAYS_YES=yes

if [ -d /home/vagrant/ ]; then
  OUTPUT="/home/vagrant/magma-build.sh"
else
  OUTPUT="/root/magma-build.sh"
fi

# Grab a snapshot of the development branch.
cat <<-EOF > $OUTPUT
#!/usr/local/bin/bash

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
sed -i "" -e "/magma.relay\[[0-9]*\].name.*/d" sandbox/etc/magma.sandbox.config
sed -i "" -e "/magma.relay\[[0-9]*\].port.*/d" sandbox/etc/magma.sandbox.config
sed -i "" -e "/magma.relay\[[0-9]*\].secure.*/d" sandbox/etc/magma.sandbox.config
printf "\n\nmagma.relay[1].name = localhost\nmagma.relay[1].port = 2525\n\n" >> sandbox/etc/magma.sandbox.config

# Bug fix... create the scan directory so ClamAV unit tests work.
if [ ! -d 'sandbox/spool/scan/' ]; then
  mkdir -p sandbox/spool/scan/
fi

# Compile the daemon and then compile the unit tests.
make -j4 all &> lib/logs/magma.txt && \
  printf "The Magma code compiled successfully.\n\n"; error

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

# Uncomment the following lines to have Magma daemonize instead of running in the foreground.
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

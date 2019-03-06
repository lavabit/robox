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

# The packages needed to compile magma.
retry pacman --sync --noconfirm --refresh m4 gc gcc patch make cmake flex binutils bison valgrind libtool autoconf pkg-config gdb gdb-common ncurses mpfr jsoncpp guile guile2.0 shared-mime-info glibc libatomic_ops libmpc libuv libxml2 libbsd libarchive python python-appdirs python-extras python-fixtures python-mimeparse python-packaging python-pbr python-pyparsing python-pyrsistent python-setuptools python-six python-testtools python-subunit

# Need to retrieve the source code.
retry pacman --sync --noconfirm --refresh git perl-error

# Needed to run the watcher and status scripts.
retry pacman --sync --noconfirm --refresh sysstat lm_sensors inotify-tools

# Needed to run the stacie script.
retry pacman --sync --noconfirm --refresh python-asn1crypto python-cffi python-idna python-ply python-pycparser python-crypto python-cryptography

# Install MaraDB.
retry pacman --sync --noconfirm --refresh  mariadb

# Append the SQL mode to the config file.
printf "\n\n[mysqld]\nsql-mode=allow_invalid_dates\n" >> /etc/mysql/my.cnf

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
    printf "\n\nmagma daemon compilation failed...\n\n";
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

# Compile the dependencies into a shared library.
dev/scripts/builders/build.lib.sh all; error

# Reset the sandbox database and storage files.
dev/scripts/database/schema.reset.sh; error

# Enable the anti-virus engine and update the signatures.
dev/scripts/freshen/freshen.clamav.sh 2>&1 | grep -v WARNING | grep -v PANIC; error
sed -i -e "s/virus.available = false/virus.available = true/g" sandbox/etc/magma.sandbox.config

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
  %{TPUT} setaf 1; ${TPUT} bold; printf "\n\nsome of the magma daemon unit tests failed...\n\n"; ${TPUT} sgr0;
  for i in 1 2 3; do
    printf "\a"; sleep 1
  done
  sleep 12
fi

# Alternatively, run the unit tests atop Valgrind.
# Note this takes awhile when the anti-virus engine is enabled.
# dev/scripts/launch/check.vg

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

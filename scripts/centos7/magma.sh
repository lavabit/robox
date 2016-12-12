#!/bin/bash
#
# Setup the the box. This runs as root

if [ -d /home/vagrant/ ]; then
  OUTPUT="/home/vagrant/magma-build.sh"
else
  OUTPUT="/root/magma-build.sh"
fi

# Grab a snapshot of the development branch.
cat <<EOF > $OUTPUT
#!/bin/bash

error() {
  if [ $? -ne 0 ]; then
    printf "\n\nmagma daemon compilation failed...\n\n";
    exit 1
  fi
}

if [ -x /usr/bin/id ]; then
  ID=`/usr/bin/id -u`
  if [ -n "$ID" -a "$ID" -eq 0 ]; then
    service mysqld start
    service havegd start
    service postfix start
    service memcached start
  fi
fi

# Temporary [hopefully] workaround to avoid [yet another] bug in NSS.
export NSS_DISABLE_HW_AES=1

# Clone the magma repository off Github.
git clone https://github.com/lavabit/magma.git magma-develop; error
cd magma-develop; error

# Clean up the permissions.
chmod g=,o= magma-develop/sandbox/etc/localhost.localdomain.pem
chmod g=,o= magma-develop/sandbox/etc/dkim.localhost.localdomain.pem

# Compile the dependencies into a shared library.
dev/scripts/builders/build.lib.sh all; error

# Compile the daemon and then compile the unit tests.
make all; error

# Reset the sandbox database and storage files.
dev/scripts/database/schema.reset.sh; error

# Enable the anti-virus engine and update the signatures.
dev/scripts/freshen/freshen.clamav.sh 2>&1 | grep -v WARNING | grep -v PANIC; error
sed -i -e "s/virus.available = false/virus.available = true/" sandbox/etc/magma.sandbox.config

# Run the unit tests.
check.run.sh; error

# Alternatively, run the unit tests atop Valgrind. 
# Note this takes awhile when the anti-virus engine is enabled.
# check.vg

# Launch the daemon.
(magma-develop/dev/scripts/launch/magma.run.sh) &

# Give the daemon time to start before exiting.
sleep 60

# Exit wit a zero so Vagrant doesn't think a failed unit test is a provision failure.
exit 0
EOF

# Make the script executable.
if [ -d /home/vagrant/ ]; then
  chown vagrant:vagrant /home/vagrant/magma-build.sh
  chmod +x /home/vagrant/magma-build.sh
else
  chmod +x /root/magma-build.sh
fi



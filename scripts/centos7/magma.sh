#!/bin/bash
#
# Setup the the box. This runs as root

# Grab a snapshot of the development branch.
cat <<EOF >/home/vagrant/magma-build.sh
#!/bin/bash

# Temporary [hopefully] workaround to avoid [yet another] bug in NSS.
export NSS_DISABLE_HW_AES=1

# Clone the magma repository off Github.
git clone https://github.com/lavabit/magma.git magma-develop

# Alternatively, grab the latest copy of the development branch using wget.
# wget https://github.com/lavabit/magma/archive/develop.tar.gz
# tar xzvf develop.tar.gz

# Linkup the scripts and clean up the permissions.
magma-develop/dev/scripts/linkup.sh
chmod g=,o= magma-develop/sandbox/etc/localhost.localdomain.pem
chmod g=,o= magma-develop/sandbox/etc/dkim.localhost.localdomain.pem

# Compile the dependencies into a shared library.
build.lib all

# Compile the daemon and then compile the unit tests.
build.magma
build.check

# Reset the sandbox database and storage files.
schema.reset

# Enable the anti-virus engine and update the signatures.
freshen.clamav 2>&1 | grep -v WARNING | grep -v PANIC
sed -i -e "s/virus.available = false/virus.available = true/" magma-develop/sandbox/etc/magma.sandbox.config

# Run the unit tests.
check.run

# Alternatively, run the unit tests atop Valgrind. 
# Note this takes awhile when the anti-virus engine is enabled.
# check.vg

# Launch the daemon.
(magma.run) &

# Give the daemon time to start before exiting.
sleep 15

# Exit wit a zero so Vagrant doesn't think a failed unit test is a provision failure.
exit 0
EOF

# Make the script executable.
chown vagrant:vagrant /home/vagrant/magma-build.sh
chmod +x /home/vagrant/magma-build.sh 


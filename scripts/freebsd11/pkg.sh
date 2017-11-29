#!/bin/bash -eux

# Disable jemalloc debugging.
ln -sf 'abort:false,junk:false' /etc/malloc.conf

# Disable crash dumps.
sysrc dumpdev="NO"

# Disabling beastie boot screen.
cat <<'EOF' >> /boot/loader.conf
beastie_disable="YES"
kern.hz=50
EOF

# Configure fetch so it retries  temprorary failures.
export FETCH_RETRY=5
export FETCH_TIMEOUT=30
export ASSUME_ALWAYS_YES=yes

pkg bootstrap
pkg-static update
pkg-static upgrade -n
pkg-static audit -F

# Generic system utils.
pkg install --yes vim curl wget sudo bash

# Since most scripts expect bash to be in the bin directory, create a symlink.
ln -s /usr/local/bin/bash /bin/bash

# Disable fortunate cookies.
sed -i -e "/fortune/d" /usr/share/skel/dot.login
sed -i -e "/fortune/d" /usr/share/skel/dot.profile
sed -i -e "/fortune/d" /usr/share/skel/dot.profile-e

sed -i -e "/fortune/d" /home/vagrant/.login
sed -i -e "/fortune/d" /home/vagrant/.profile

# Update the locate database.
/etc/periodic/weekly/310.locate

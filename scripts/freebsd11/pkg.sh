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

pkg bootstrap --yes
pkg-static update --yes
pkg-static upgrade -n --yes
pkg-static audit -F --yes

# Generic system utils.
pkg install --yes vim curl wget sudo

# Disable fortunate cookies.
sed -i -e "/fortune/d" /usr/share/skel/dot.login
sed -i -e "/fortune/d" /usr/share/skel/dot.profile
sed -i -e "/fortune/d" /usr/share/skel/dot.profile-e

sed -i -e "/fortune/d" /home/vagrant/.login
sed -i -e "/fortune/d" /home/vagrant/.profile

# Update the locate database.
/etc/periodic/weekly/310.locate

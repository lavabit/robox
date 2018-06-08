#!/bin/bash -eux

# Configure fetch so it retries  temprorary failures.
export FETCH_RETRY=5
export FETCH_TIMEOUT=30
export ASSUME_ALWAYS_YES=yes

# Force the use of HTTPS for package updates.
mkdir -p /usr/local/etc/pkg/repos/
echo 'FreeBSD: { url: "pkg+https://pkg.FreeBSD.org/${ABI}/quarterly" }' > /usr/local/etc/pkg/repos/FreeBSD.conf

pkg bootstrap
pkg-static update --force
pkg-static upgrade --yes --force

# Generic system utils.
pkg install --yes vim curl wget sudo bash gnuls gnugrep

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

# Configure daily locate database updates.
echo '# 315.locate' >> /etc/periodic.conf
echo 'daily_locate_enable="YES" # Update locate daily' >> /etc/periodic.conf
cp /etc/periodic/weekly/310.locate /usr/local/etc/periodic/daily/315.locate
sed -i -e "s/weekly_locate_enable/daily_locate_enable=/g" /usr/local/etc/periodic/daily/315.locate

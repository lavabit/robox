#!/bin/bash -eux

# Configure fetch so it retries  temporary failures.
export FETCH_RETRY=5
export FETCH_TIMEOUT=30
export ASSUME_ALWAYS_YES=yes

# We need to use HTTP until the CA bundle has been updated.
mkdir -p /usr/local/etc/pkg/repos/
rm /var/db/pkg/FreeBSD.meta /var/db/pkg/repo-FreeBSD.sqlite
echo 'FreeBSD: { url: "pkg+http://pkg.FreeBSD.org/${ABI}/latest" }' > /usr/local/etc/pkg/repos/FreeBSD.conf

# Install the packages needed to update the CA bundle.
pkg bootstrap
pkg-static update -f
pkg-static upgrade --yes perl5 p5-MIME-Base64 p5-Carp curl ca_root_nss

# Download the bundle generator.
curl --silent --location --output $HOME/mk-ca-bundle.pl https://raw.githubusercontent.com/curl/curl/85f91248cffb22d151d5983c32f0dbf6b1de572a/lib/mk-ca-bundle.pl
sha256 -c f819e5844935bad3d7eebab566b55066f21bd7138097d2baab7842bd04fd92d2 $HOME/mk-ca-bundle.pl || exit 1
chmod +x $HOME/mk-ca-bundle.pl

# To ensure we save the certdata.txt file in a predictable place we change directory first.
cd $HOME && $HOME/mk-ca-bundle.pl $HOME/ca-bundle.crt

# Move the updated bundle to all the places it might be needed.
cp $HOME/ca-bundle.crt /etc/ssl/cert.pem
cp $HOME/ca-bundle.crt /usr/local/openssl/cert.pem
cp $HOME/ca-bundle.crt /usr/local/etc/ssl/cert.pem
cp $HOME/ca-bundle.crt /usr/local/share/certs/ca-root-nss.crt

# Cleanup the downloaded files and clear the cached repo data.
rm $HOME/ca-bundle.crt $HOME/certdata.txt $HOME/mk-ca-bundle.pl /var/db/pkg/FreeBSD.meta /var/db/pkg/repo-FreeBSD.sqlite

# Switch to using HTTPS and perform the system upgrade.
echo 'FreeBSD: { url: "pkg+https://pkg.FreeBSD.org/${ABI}/latest" }' > /usr/local/etc/pkg/repos/FreeBSD.conf
pkg-static update -f
pkg-static upgrade --yes

# Generic system utils.
pkg-static upgrade --yes vim curl wget sudo bash gnuls gnugrep psmisc

# Since most scripts expect bash to be in the bin directory, create a symlink.
ln -s /usr/local/bin/bash /bin/bash

# Disable fortunate cookies.
sed -i "" -e "/fortune/d" /usr/share/skel/dot.login
sed -i "" -e "/fortune/d" /usr/share/skel/dot.profile

sed -i "" -e "/fortune/d" /home/vagrant/.login
sed -i "" -e "/fortune/d" /home/vagrant/.profile

# Update the locate database.
/etc/periodic/weekly/310.locate

# Configure daily locate database updates.
echo '# 315.locate' >> /etc/periodic.conf
echo 'daily_locate_enable="YES" # Update locate daily' >> /etc/periodic.conf
cp /etc/periodic/weekly/310.locate /usr/local/etc/periodic/daily/315.locate
sed -i "" -e "s/weekly_locate_enable/daily_locate_enable=/g" /usr/local/etc/periodic/daily/315.locate

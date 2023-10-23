#!/bin/sh

# Setup an HTTP package mirror so we can download cURL.
echo "http://mirrors.lavabit.com/openbsd/" > /etc/installurl

# Install cURL.
pkg_add -I curl

# The certificate authority file needs to be updated so that
# HTTPS can be used to download updates/packages. We start by 
# downloading the helper script. If the GitHub certificate fails, 
# add the "--insecure" flag to overcome the it. We check the downloaded
# file hash, so it should be safe.
curl --silent --location --output $HOME/mk-ca-bundle.pl https://raw.githubusercontent.com/curl/curl/85f91248cffb22d151d5983c32f0dbf6b1de572a/lib/mk-ca-bundle.pl
echo "SHA256 ($HOME/mk-ca-bundle.pl) = f819e5844935bad3d7eebab566b55066f21bd7138097d2baab7842bd04fd92d2" | sha256 -c || exit 1
chmod +x $HOME/mk-ca-bundle.pl

# To ensure we save the certdata.txt file in a predictable place we change directories first.
cd $HOME && $HOME/mk-ca-bundle.pl $HOME/ca-bundle.crt
cp $HOME/ca-bundle.crt /etc/ssl/cert.pem

# Cleanup the files used to update the CA file and then switch to using HTTPS for package downloads.
rm $HOME/ca-bundle.crt $HOME/certdata.txt $HOME/mk-ca-bundle.pl
echo "https://mirrors.lavabit.com/openbsd/" > /etc/installurl

# Update the system.
pkg_add -u

# Install a few basic tools.
pkg_add -I curl wget bash sudo-- vim--no_x11

# Since most scripts expect bash to be in the bin directory, create a symlink.
[ ! -f /bin/bash ] && [ -f  /usr/local/bin/bash ] && ln -s /usr/local/bin/bash /bin/bash
[ ! -f /usr/bin/bash ] && [ -f  /usr/local/bin/bash ] && ln -s /usr/local/bin/bash /usr/bin/bash

# Some hypervisors require this to run OpenBSD properly.
echo "kern.allowkmem=1" > /etc/sysctl.conf

# Initialize the locate database.
ln -s /usr/libexec/locate.updatedb /usr/bin/updatedb
/usr/libexec/locate.updatedb

# Reboot gracefully.
( shutdown -r +1 ) &
exit 0


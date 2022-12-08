#!/bin/bash -eux

# Setup the memory locking limits.
sed -i -e "s/.*rc_ulimit.*/rc_ulimit=\"-l unlimited\"/g" /etc/rc.conf

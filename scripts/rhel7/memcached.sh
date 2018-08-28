#!/bin/bash -eux

# Install memcached.
yum install --assumeyes libevent memcached

# Setup memcached to start automatically.
systemctl start memcached.service && systemctl enable memcached.service

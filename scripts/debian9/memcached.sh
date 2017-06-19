#!/bin/bash -eux

# The memcached server.
apt-get --assume-yes install memcached libevent-dev

# Setup memcached to start automatically.
systemctl start memcached.service && systemctl enable memcached.service

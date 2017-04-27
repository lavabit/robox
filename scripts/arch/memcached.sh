#!/bin/bash -eux

# Update the package database.
pacman --sync --noconfirm memcached libevent

# Setup memcached to start automatically.
systemctl start memcached.service && systemctl enable memcached.service

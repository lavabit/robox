#!/bin/bash -eux

# The memcached server.
apk add --force memcached libevent

# Setup memcached to start automatically.
rc-update add memcached default && rc-service memcached start

#!/bin/bash -eux

# Setup memcached to start automatically.
systemctl enable memcached.service
systemctl start memcached.service

#!/bin/bash -eux

# Remove orphans.
pkg-static autoremove --yes

# Clean the package cache.
pkg-static clean --yes --all
rm -f /var/db/pkg/repo-FreeBSD.sqlite

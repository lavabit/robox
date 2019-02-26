#!/bin/bash -eux

# Clean the package cache. One clean param removes packages that are no longer
# installed. The second clean param removes the entire cache.
pacman --sync --noconfirm --clean --clean

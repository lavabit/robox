#!/bin/sh -eux

# Setup the apk cache.
setup-apkcache /var/cache/apk

# Delete unnecessary packages, and download any missing packages.
apk cache -v sync

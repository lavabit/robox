#!/bin/bash -eux

# Works around a bug which slows down DNS queries on Virtualbox.
# https://access.redhat.com/site/solutions/58625 (subscription required)
# http://www.linuxquestions.org/questions/showthread.php?p=4399340#post4399340

# Bail if we are not running inside VirtualBox.
if [[ "$PACKER_BUILDER_TYPE" != virtualbox-iso ]]; then
    exit 0
fi

# Include single-request-reopen in the auto-generated resolv.conf.
printf "Fixing the problem with slow DNS queries.\n"
echo 'RES_OPTIONS="single-request-reopen"' >> /etc/sysconfig/network
service network restart

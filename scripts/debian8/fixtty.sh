#!/bin/bash -eux

# Fix the no tty bug with vagrant.
# https://github.com/mitchellh/vagrant/issues/1673
sed -i -e 's,^.*:/sbin/getty\s\+.*\s\+tty[2-6],#\0,' /etc/inittab

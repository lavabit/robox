#!/bin/bash -eux

# Fix the no tty bug with vagrant.
# https://github.com/mitchellh/vagrant/issues/1673
sed -i '/tty/!s/mesg n/tty -s \\&\\& mesg n/' /root/.profile

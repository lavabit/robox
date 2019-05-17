#!/bin/bash -eux

# Fix the no tty bug with vagrant.
# https://github.com/mitchellh/vagrant/issues/1673

sed -i -e 's,^\(ACTIVE_CONSOLES="/dev/tty\).*,\11",' /etc/default/console-setup
for f in /etc/init/tty[^1]*.conf; do
  rm --force "$f"
done

#!/bin/bash

# Delete the machine-id file so a new value gets generated during subsequent reboots.

if [ -f /etc/machine-id ]; then
  truncate --size=0 /etc/machine-id
fi

if [ -f /run/machine-id ]; then
  truncate --size=0 /run/machine-id
fi

# printf "@reboot root command bash -c '/usr/bin/systemd-machine-id-setup ; rm --force /etc/cron.d/machine-id'\n" > /etc/cron.d/machine-id


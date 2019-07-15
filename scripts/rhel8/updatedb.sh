#!/bin/bash -eux

dnf --assumeyes install mlocate

# Update the locate database.
# cp /etc/cron.daily/mlocate.cron /etc/cron.hourly/mlocate.cron && /etc/cron.daily/mlocate.cron

# A very simple script designed to ensure the locate database gets updated
# automatically when the box is booted and provisioned.
printf "@reboot root bash -c '/bin/updatedb ; rm --force /etc/cron.d/updatedb'\n" > /etc/cron.d/updatedb
chcon "system_u:object_r:system_cron_spool_t:s0" /etc/cron.d/updatedb

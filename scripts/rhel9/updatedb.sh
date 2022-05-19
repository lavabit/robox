#!/bin/bash -eux

dnf --assumeyes install mlocate

# Override the default mlocate timer so it runs every hour.
if [ ! -d /etc/systemd/system/mlocate-updatedb.timer.d/ ]; then
  mkdir --parents /etc/systemd/system/mlocate-updatedb.timer.d/
fi

chcon system_u:object_r:systemd_unit_file_t:s0 /etc/systemd/system/mlocate-updatedb.timer.d/
chmod 755 /etc/systemd/system/mlocate-updatedb.timer.d/

cat <<-EOF > /etc/systemd/system/mlocate-updatedb.timer.d/override.conf
[Unit]
Description=Updates mlocate database every hour

[Timer]
OnCalendar=hourly
AccuracySec=1h
EOF

chcon system_u:object_r:systemd_unit_file_t:s0 /etc/systemd/system/mlocate-updatedb.timer.d/override.conf
chmod 644 /etc/systemd/system/mlocate-updatedb.timer.d/override.conf

# Force systemd to load the new unit file, and ensure the timer is enabled.
systemctl daemon-reload && systemctl enable mlocate-updatedb.timer

# A very simple script designed to ensure the locate database gets updated
# automatically when the box is booted and provisioned.
printf "@reboot root bash -c '/bin/updatedb ; rm --force /etc/cron.d/updatedb'\n" > /etc/cron.d/updatedb
chcon "system_u:object_r:system_cron_spool_t:s0" /etc/cron.d/updatedb

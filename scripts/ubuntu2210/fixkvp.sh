#!/bin/bash -eux

# Fix to prevent the kv-kvp-daemon from hanging for 90 seconds during boot.
# https://bugs.launchpad.net/ubuntu/+source/linux/+bug/1820063


# Disable the daemon to remove the symlihk.
systemctl disable hv-kvp-daemon.service

# Override the default unit file with a version that won't hang during boot ups.
cat <<-EOF > /etc/systemd/system/multi-user.target.wants/hv-kvp-daemon.service
[Unit]
Description=Hyper-V KVP Protocol Daemon
ConditionVirtualization=microsoft
ConditionPathExists=/dev/vmbus/hv_kvp
DefaultDependencies=no
BindsTo=sys-devices-virtual-misc-vmbus\x21hv_kvp.device
After=systemd-remount-fs.service
Before=shutdown.target cloud-init-local.service walinuxagent.service
Conflicts=shutdown.target
RequiresMountsFor=/var/lib/hyperv

[Service]
ExecStart=/usr/sbin/hv_kvp_daemon -n

[Install]
WantedBy=multi-user.target

EOF

#!/bin/bash -eux

# Install haveged, which should improve the entropy pool performance
# inside a virtual machines, but be careful, it doesn't end up running
# on systems which aren't virtualized. The patch command is included
# to ensure its use below doesn't cause an error.
yum --assumeyes install haveged patch

# Enable and start the daemons.
systemctl enable haveged
systemctl start haveged

# Improve the kernel entropy performance.
printf "kernel.random.read_wakeup_threshold = 64\n" >> /etc/sysctl.d/50-random.conf
printf "kernel.random.write_wakeup_threshold = 3072\n" >> /etc/sysctl.d/50-random.conf
chcon "system_u:object_r:etc_t:s0" /etc/sysctl.d/50-random.conf

# If the haveged daemon is installed, this patch will speed it up even more.
if [ -f /usr/lib/systemd/system/haveged.service ]; then
patch /usr/lib/systemd/system/haveged.service <<-EOF
diff --git a/haveged.service b/haveged.service
index 2b79f3f..bbf037d 100644
--- a/haveged.service
+++ b/haveged.service
@@ -4,7 +4,7 @@ Documentation=man:haveged(8) http://www.issihosts.com/haveged/

 [Service]
 Type=simple
-ExecStart=/usr/sbin/haveged -w 1024 -v 1 --Foreground
+ExecStart=/usr/sbin/haveged -w 3072 -v 1 --Foreground
 SuccessExitStatus=143

 [Install]
EOF
fi

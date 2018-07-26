#!/bin/bash

# Improve the kernel entropy performance.
printf "kernel.random.read_wakeup_threshold = 64\n" >> /etc/sysctl.d/50-random.conf
printf "kernel.random.write_wakeup_threshold = 3072\n" >> /etc/sysctl.d/50-random.conf
chcon "system_u:object_r:etc_t:s0" /etc/sysctl.d/50-random.conf

# If the haveged daemon is installed, this patch will speed it up even more.
if [ -f /etc/init.d/haveged ]; then
patch /etc/init.d/haveged <<-EOF
diff --git a/haveged b/haveged
index 8f4c1c6..e95c0a9 100755
--- a/haveged
+++ b/haveged
@@ -37,7 +37,7 @@ test -x \${HAVEGED_BIN} || { echo "Cannot find haveged executable \${HAVEGED_BIN}"
 case "$1" in
 start)
   echo -n \$"Starting \$prog: "
-  \${HAVEGED_BIN} -w 1024 -v 1 && success || failure
+  \${HAVEGED_BIN} -w 3072 -v 1 && success || failure
   RETVAL=\$?
   [ "\$RETVAL" = 0 ] && touch \${LOCKFILE}
   echo
EOF
fi

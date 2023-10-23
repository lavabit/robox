#!/bin/bash -x

retry() {
  local COUNT=1
  local DELAY=0
  local RESULT=0
  while [[ "${COUNT}" -le 10 ]]; do
    [[ "${RESULT}" -ne 0 ]] && {
      [ "`which tput 2> /dev/null`" != "" ] && [ -n "$TERM" ] && tput setaf 1
      echo -e "\n${*} failed... retrying ${COUNT} of 10.\n" >&2
      [ "`which tput 2> /dev/null`" != "" ] && [ -n "$TERM" ] && tput sgr0
    }
    "${@}" && { RESULT=0 && break; } || RESULT="${?}"
    COUNT="$((COUNT + 1))"

    # Increase the delay with each iteration.
    DELAY="$((DELAY + 10))"
    sleep $DELAY
  done

  [[ "${COUNT}" -gt 10 ]] && {
    [ "`which tput 2> /dev/null`" != "" ] && [ -n "$TERM" ] && tput setaf 1
    echo -e "\nThe command failed 10 times.\n" >&2
    [ "`which tput 2> /dev/null`" != "" ] && [ -n "$TERM" ] && tput sgr0
  }

  return "${RESULT}"
}

# Install haveged, which should improve the entropy pool performance
# inside a virtual machines, but be careful, it doesn't end up running
# on systems which aren't virtualized. The patch command is included
# to ensure its use below doesn't cause an error.
retry yum --assumeyes install haveged patch

# Enable and start the daemons.
chkconfig haveged on
service haveged start

# Improve the kernel entropy performance.
printf "kernel.random.read_wakeup_threshold = 64\n" >> /etc/sysctl.d/50-random.conf
printf "kernel.random.write_wakeup_threshold = 3072\n" >> /etc/sysctl.d/50-random.conf
chcon "system_u:object_r:etc_t:s0" /etc/sysctl.d/50-random.conf

# This patch should increase the available entropy pool even more.
if [ -f /etc/init.d/haveged ]; then
patch /etc/init.d/haveged <<-EOF
diff --git a/haveged b/haveged
index 8f4c1c6..e95c0a9 100755
--- a/haveged
+++ b/haveged
@@ -37,7 +37,7 @@ test -x \${HAVEGED_BIN} || { echo "Cannot find haveged executable \${HAVEGED_BIN}"
 case "\$1" in
 start)
   echo -n \$"Starting \$prog: "
-  \${HAVEGED_BIN} -w 1024 -v 1 && success || failure
+  \${HAVEGED_BIN} -w 3072 -v 1 && success || failure
   RETVAL=\$?
   [ "\$RETVAL" = 0 ] && touch \${LOCKFILE}
   echo
EOF
fi

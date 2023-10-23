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

retry dnf --assumeyes install plocate

# Override the default plocate timer so it runs every hour.
if [ ! -d /etc/systemd/system/plocate-updatedb.timer.d/ ]; then
  mkdir --parents /etc/systemd/system/plocate-updatedb.timer.d/
fi

chcon system_u:object_r:systemd_unit_file_t:s0 /etc/systemd/system/plocate-updatedb.timer.d/
chmod 755 /etc/systemd/system/plocate-updatedb.timer.d/

cat <<-EOF > /etc/systemd/system/plocate-updatedb.timer.d/override.conf
[Unit]
Description=Updates plocate database every hour

[Timer]
OnCalendar=hourly
AccuracySec=1h
EOF

chcon system_u:object_r:systemd_unit_file_t:s0 /etc/systemd/system/plocate-updatedb.timer.d/override.conf
chmod 644 /etc/systemd/system/plocate-updatedb.timer.d/override.conf

# Force systemd to load the new unit file, and ensure the timer is enabled.
systemctl daemon-reload && systemctl enable plocate-updatedb.timer

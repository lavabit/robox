#!/bin/bash -eux

retry() {
  local COUNT=1
  local RESULT=0
  while [[ "${COUNT}" -le 10 ]]; do
    [[ "${RESULT}" -ne 0 ]] && {
      [ "`which tput 2> /dev/null`" != "" ] && tput setaf 1
      echo -e "\n${*} failed... retrying ${COUNT} of 10.\n" >&2
      [ "`which tput 2> /dev/null`" != "" ] && tput sgr0
    }
    "${@}" && { RESULT=0 && break; } || RESULT="${?}"
    COUNT="$((COUNT + 1))"

    # Increase the delay with each iteration.
    DELAY="$((DELAY + 10))"
    sleep $DELAY
  done

  [[ "${COUNT}" -gt 10 ]] && {
    [ "`which tput 2> /dev/null`" != "" ] && tput setaf 1
    echo -e "\nThe command failed 10 times.\n" >&2
    [ "`which tput 2> /dev/null`" != "" ] && tput sgr0
  }

  return "${RESULT}"
}

retry yum --assumeyes install mlocate

# Update the locate database.
cp /etc/cron.daily/mlocate /etc/cron.hourly/mlocate && /etc/cron.daily/mlocate

# A very simple script designed to ensure the locate database gets updated
# automatically when the box is booted and provisioned.
printf "@reboot root bash -c '/usr/bin/updatedb ; rm --force /etc/cron.d/updatedb'\n" > /etc/cron.d/updatedb
chcon "system_u:object_r:system_cron_spool_t:s0" /etc/cron.d/updatedb

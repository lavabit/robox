#!/bin/bash -eux

retry() {
  local COUNT=1
  local DELAY=0
  local RESULT=0
  while [[ "${COUNT}" -le 10 ]]; do
    [[ "${RESULT}" -ne 0 ]] && {
      [ "`which tput 2> /dev/null`" != "" ] && [ -n "$TERM" ] && tput setaf 1
      echo -e "\\n${*} failed... retrying ${COUNT} of 10.\\n" >&2
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
    echo -e "\\nThe command failed 10 times.\\n" >&2
    [ "`which tput 2> /dev/null`" != "" ] && [ -n "$TERM" ] && tput sgr0
  }

  return "${RESULT}"
}

# Update the package database.
retry pacman --sync --noconfirm --refresh postfix libmariadbclient lzo postgresql-libs tinycdb

# Update the system packages.
# pacman --sync --noconfirm --refresh --sysupgrade

# Configure postfix to listen for relays on port 2525 so it doesn't conflict with magma.
sed -i -e "s/^smtp\([ ]*inet\)/127.0.0.1:2525\1/" /etc/postfix/master.cf

# Configure the postfix hostname and origin parameters.
printf "\ninet_interfaces = localhost\n" >> /etc/postfix/main.cf
printf "myhostname = relay.magma.localdomain\n" >> /etc/postfix/main.cf
printf "myorigin = magma.localdomain\n" >> /etc/postfix/main.cf
printf "transport_maps = hash:/etc/postfix/transport\n" >> /etc/postfix/main.cf

# printf "magma.localdomain         smtp:[127.0.0.1]:7000\n" >> /etc/postfix/transport
# postmap /etc/postfix/transport

# Setup postfix to start automatically.
systemctl start postfix.service && systemctl enable postfix.service

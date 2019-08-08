#!/bin/bash -eux

retry() {
  local COUNT=1
  local RESULT=0
  while [[ "${COUNT}" -le 10 ]]; do
    [[ "${RESULT}" -ne 0 ]] && {
      [ "`which tput 2> /dev/null`" != "" ] && tput setaf 1
      echo -e "\\n${*} failed... retrying ${COUNT} of 10.\\n" >&2
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
    echo -e "\\nThe command failed 10 times.\\n" >&2
    [ "`which tput 2> /dev/null`" != "" ] && tput sgr0
  }

  return "${RESULT}"
}

# Ensure dmidecode is available.
retry apk add dmidecode

# Bail if we are not running atop QEMU.
if [[ `dmidecode -s system-product-name` != "KVM" && `dmidecode -s system-manufacturer` != "QEMU" ]]; then
    exit 0
fi

# Install the QEMU using Yum.
printf "Installing the QEMU Tools.\n"

# Install the QEMU guest tools.
retry apk add qemu-guest-agent

# Update the default agent path.
printf "\nGA_METHOD=\"virtio-serial\"\nGA_PATH=\"/dev/vport0p1\"\n" >> /etc/conf.d/qemu-guest-agent

# Autostart the open-vm-tools.
rc-update add qemu-guest-agent default && rc-service qemu-guest-agent start

# Boosts the available entropy which allows magma to start faster.
retry apk add haveged

# Remove the network need from the haveged.
tee /etc/init.d/haveged <<-EOF
#!/sbin/openrc-run

command="/usr/sbin/haveged"
command_args="$HAVEGED_OPTS"
command_background="yes"

pidfile="/run/$RC_SVCNAME.pid"

EOF

chmod 755 /etc/init.d/haveged

# Autostart the haveged daemon.
rc-update add haveged default && rc-service haveged start

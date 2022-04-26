#!/bin/bash -eux

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

# Configure fetch so it retries  temprorary failures.
export FETCH_RETRY=5
export FETCH_TIMEOUT=30
export ASSUME_ALWAYS_YES=yes

# Ensure dmideocode is available.
retry pkg-static install --yes dmidecode

# Bail if we are not running inside VMWare.
if [[ `dmidecode -s system-product-name` != "VMware Virtual Platform" ]]; then
    exit 0
fi

retry pkg-static install --yes open-vm-tools-nox11

# Disable vmxnet in favor of whatever the OpenVM Tools are suggesting.
sed -i -e 's#^ifconfig_vmx0#ifconfig_em0#g' /etc/rc.conf
sed -i -e '/^if_vmx_load=.*/d' /boot/loader.conf

sysrc vmware_guest_vmblock_enable=YES
sysrc vmware_guest_vmhgfs_enable=YES
sysrc vmware_guest_vmmemctl_enable=YES
sysrc vmware_guest_vmxnet_enable=YES
sysrc vmware_guestd_enable=YES

sysrc rpcbind_enable="YES"
sysrc rpc_lockd_enable="YES"
sysrc nfs_client_enable="YES"

rm -f /root/freebsd.iso

# Fix the SSH NAT issue on VMWare systems.
printf "\nIPQoS lowdelay throughput\n" >> /etc/ssh/sshd_config

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

# Configure fetch so it retries  temprorary failures.
export FETCH_RETRY=5
export FETCH_TIMEOUT=30
export ASSUME_ALWAYS_YES=yes

# Ensure dmideocode is available.
retry pkg-static install --yes dmidecode

# Bail if we are not running atop QEMU.
if [[ `dmidecode -s system-product-name` != "KVM" && `dmidecode -s system-manufacturer` != "QEMU" ]]; then
    exit 0
fi

# Load the virtio module at boot.
echo 'if_vtnet_load="YES"' >> /boot/loader.conf
echo 'virtio_load="YES"' >> /boot/loader.conf
echo 'virtio_pci_load="YES"' >> /boot/loader.conf
echo 'virtio_blk_load="YES"' >> /boot/loader.conf
echo 'virtio_scsi_load="YES"' >> /boot/loader.conf
echo 'virtio_console_load="YES"' >> /boot/loader.conf
echo 'virtio_balloon_load="YES"' >> /boot/loader.conf
echo 'virtio_random_load="YES"' >> /boot/loader.conf

# Enable the daemons used for host to geust communication.
sysrc rpcbind_enable="YES"
sysrc rpc_lockd_enable="YES"
sysrc nfs_client_enable="YES"

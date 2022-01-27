#!/bin/bash

retry() {
  local COUNT=1
  local RESULT=0
  while [[ "${COUNT}" -le 10 ]]; do
    [[ "${RESULT}" -ne 0 ]] && {
      [ "`which tput 2> /dev/null`" != "" ] && [ ! -z "$TERM" ] && tput setaf 1
      echo -e "\n${*} failed... retrying ${COUNT} of 10.\n" >&2
      [ "`which tput 2> /dev/null`" != "" ] && [ ! -z "$TERM" ] && tput sgr0
    }
    "${@}" && { RESULT=0 && break; } || RESULT="${?}"
    COUNT="$((COUNT + 1))"

    # Increase the delay with each iteration.
    DELAY="$((DELAY + 10))"
    sleep $DELAY
  done

  [[ "${COUNT}" -gt 10 ]] && {
    [ "`which tput 2> /dev/null`" != "" ] && [ ! -z "$TERM" ] && tput setaf 1
    echo -e "\nThe command failed 10 times.\n" >&2
    [ "`which tput 2> /dev/null`" != "" ] && [ ! -z "$TERM" ] && tput sgr0
  }

  return "${RESULT}"
}

error() {
	if [ $? -ne 0 ]; then
			printf "\n\nvmware install failed...\n\n";
			exit 1
	fi
}


# Bail if we are not running inside VMWare.
if [[ `dmidecode -s system-product-name` != "VMware Virtual Platform" ]]; then
    exit 0
fi

# Install the VMWare Tools.
printf "Installing the VMWare Tools.\n"

# The developer desktop builds need the desktop tools/drivers.
if [[ "$PACKER_BUILD_NAME" =~ ^magma-developer-(vmware|hyperv|libvirt|parallels|virtualbox)$ ]]; then
  yum --quiet --assumeyes install open-vm-tools open-vm-tools-desktop fuse-libs libdnet libicu libmspack
else
  yum --quiet --assumeyes install open-vm-tools fuse-libs libdnet libicu libmspack
fi

if [ ! -d /var/run/vmware ]; then
  mkdir --parents /var/run/vmware
fi

chkconfig vmtoolsd on
service vmtoolsd start

#mkdir -p /mnt/vmware; error
#mount -o loop /root/linux.iso /mnt/vmware; error

#cd /tmp; error
#tar xzf /mnt/vmware/VMwareTools-*.tar.gz; error

#umount /mnt/vmware; error
rm -rf /root/linux.iso; error

#/tmp/vmware-tools-distrib/vmware-install.pl -d; error
#rm -rf /tmp/vmware-tools-distrib; error

# Fix the SSH NAT issue on VMWare systems.
printf "\nIPQoS lowdelay throughput\n" >> /etc/ssh/sshd_config

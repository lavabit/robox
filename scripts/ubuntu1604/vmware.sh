#!/bin/bash

retry() {
  local COUNT=1
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

# The Ubuntu cloud tools package automatically installs kernel drivers and background
# services for several virtualization platforms. Crude runtime dependency checks should
# block unnecessary drivers from loading, and unnecessary services from starting, but this 
# strategy still generates spurious log messages, along with an (albeit slight) performance
# penalty. So reduce noise, and avoid any performance penalties we disable and mask 
# guest drivers/services which don't match the target virtualization platform.
systemctl --quiet is-enabled hv-fcopy-daemon.service &> /dev/null && \
  ( systemctl disable hv-fcopy-daemon.service ; systemctl mask hv-fcopy-daemon.service ) || \
  echo "hv-fcopy-daemon.service already disabled" &> /dev/null
systemctl --quiet is-enabled hv-kvp-daemon.servicee &> /dev/null && \
  ( systemctl disable hv-kvp-daemon.service ; systemctl mask hv-kvp-daemon.service ) || \
  echo "hv-kvp-daemon.service already disabled" &> /dev/null
systemctl --quiet is-enabled hv-vss-daemon.servicee &> /dev/null && \
  ( systemctl disable hv-vss-daemon.service ; systemctl mask hv-vss-daemon.service ) || \
  echo "hv-vss-daemon.servicee already disabled" &> /dev/null
systemctl --quiet is-enabled virtualbox-guest-utils.service &> /dev/null && \
  ( systemctl disable virtualbox-guest-utils.service ; systemctl mask virtualbox-guest-utils.service ) || \
  echo "virtualbox-guest-utils.service already disabled" &> /dev/null


# Install the VMWare Tools from the Linux ISO.
printf "Installing the VMWare Tools.\n"

# To allow for automated installs, we disable interactive configuration steps.
export DEBIAN_FRONTEND=noninteractive
export DEBCONF_NONINTERACTIVE_SEEN=true

retry apt-get --assume-yes install open-vm-tools ethtool libdumbnet1 zerofree
systemctl enable open-vm-tools.service
systemctl start open-vm-tools.service

#mkdir -p /mnt/vmware; error
#mount -o loop /root/linux.iso /mnt/vmware; error

#cd /tmp; error
#tar xzf /mnt/vmware/VMwareTools-*.tar.gz; error

#umount /mnt/vmware; error
rm -rf /root/linux.iso; error

#/tmp/vmware-tools-distrib/vmware-install.pl -d; error
#rm -rf /tmp/vmware-tools-distrib; error

# Boosts the available entropy which allows magma to start faster.
retry apt-get --assume-yes install haveged; error

# Autostart the haveged daemon.
systemctl enable haveged.service

# Fix the SSH NAT issue on VMWare systems.
printf "\nIPQoS lowdelay throughput\n" >> /etc/ssh/sshd_config

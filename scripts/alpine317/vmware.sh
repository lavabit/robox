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

# Ensure dmidecode is available.
retry apk add dmidecode

# Bail if we are not running inside VMWare.
if [[ `dmidecode -s system-product-name` != "VMware Virtual Platform" ]]; then
    exit 0
fi

# Install the VMWare Tools from the Linux ISO.
printf "Installing the VMWare Tools.\n"

# Update the APK cache.
retry apk update

# Install the Open VMWare Tools.
retry apk add perl build-base mkinitfs util-linux linux-pam linux-headers
retry apk add open-vm-tools open-vm-tools-dev

# Autostart the open-vm-tools.
rc-update add open-vm-tools default && rc-service open-vm-tools start
vmware-toolbox-cmd timesync enable

# Update sshd so it checks the networking service instead of the net-online service.
sed -i -e "s/rc_need=.*/rc_need=\"networking\"/g" /etc/conf.d/sshd

# Ensure the OpenVM tools don't start until after the SSH server is online.
printf 'rc_need="sshd"\n' >> /etc/conf.d/open-vm-tools
rc-update -u

tee /etc/udev/rules.d/60-open-vm-tools.rules <<-EOF
# VMware SCSI devices Timeout adjustment
#
# Modify the timeout value for VMware SCSI devices so that
# in the event of a failover, we don't time out.
# See Bug 271286 for more information.

ACTION=="add|change", SUBSYSTEMS=="scsi", ATTRS{vendor}=="VMware  " , ATTRS{model}=="Virtual disk    ",   RUN+="/bin/sh -c 'echo 180 >/sys$DEVPATH/device/timeout'"


# VMWare Virtual Sockets permissions
#
# after loading the vsock module, a block device /dev/vsock will be created with permission 0600
# This rule changes permission to 0666 to allow users access to the virtual sockets

KERNEL=="vsock", MODE="0666"
EOF

# Boosts the available entropy which allows magma to start faster.
retry apk add haveged

# Autostart the haveged daemon.
rc-update add haveged default && rc-service haveged start

# # The VMWare tool dependencies.
# apk add perl build-base mkinitfs util-linux linux-pam linux-headers
#
# mkdir /etc/rc.d/
# mkdir /etc/rc.d/rc0.d/
# mkdir /etc/rc.d/rc1.d/
# mkdir /etc/rc.d/rc2.d/
# mkdir /etc/rc.d/rc3.d/
# mkdir /etc/rc.d/rc4.d/
# mkdir /etc/rc.d/rc5.d/
# mkdir /etc/rc.d/rc6.d/
#
# # Uncomment if you'd prefer to build the guest additions from source.
# export PATH=/usr/glibc-compat/bin:/usr/glibc-compat/sbin:/usr/bin/:$PATH
# export LD_LIBRARY_PATH="/usr/glibc-compat/lib/"
#
# cd /tmp
# mkdir -p /media/vmware
# losetup /dev/loop0 /root/linux.iso
# mount -t iso9660 -o ro /dev/loop0 /media/vmware
#
# tar xzf /media/vmware/VMwareTools-*.tar.gz
# sed -i -e "s/need_glibc25='yes'/need_glibc25='no'/g" /tmp/vmware-tools-distrib/vmware-install.pl
# /tmp/vmware-tools-distrib/vmware-install.pl -d
# umount /media/vmware && rmdir /media/vmware
# rm -rf /tmp/vmware-tools-distrib
#
# sed -i -e "s/have_grabbitmqproxy='yes'/have_grabbitmqproxy='no'/g" /usr/bin/vmware-config-tools.pl
# sed -i -e "s/have_thinprint='yes'/have_thinprint='no'/g" /usr/bin/vmware-config-tools.pl
# sed -i -e "s/have_caf='yes'/have_caf='no'/g" /usr/bin/vmware-config-tools.pl
# sed -i -e "s/need_glibc25='yes'/need_glibc25='no'/g" /usr/bin/vmware-config-tools.pl
# /usr/bin/vmware-config-tools.pl -d
#
# sed -i -e "s/have_caf=yes/have_caf=no/g" /etc/rc.d/vmware-tools
# cat <<-EOF > /etc/init.d/vmware-tools
# #!/sbin/openrc-run
#
# command="/etc/rc.d/vmware-tools"
# command_args="start"
# command_background="yes"
#
# pidfile="/run/$RC_SVCNAME.pid"
#
# EOF
# chmod +x /etc/init.d/vmware-tools
# rc-update add vmware-tools default && rc-service vmware-tools start
# rc-update -u

# When we're done delete the tools ISO.
rm -rf /root/linux.iso

# Fix the SSH NAT issue on VMWare systems.
printf "\nIPQoS lowdelay throughput\n" >> /etc/ssh/sshd_config

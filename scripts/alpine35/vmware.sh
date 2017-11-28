#!/bin/bash -eux

# Ensure dmidecode is available.
apk add dmidecode

# Bail if we are not running inside VMWare.
if [[ `dmidecode -s system-product-name` != "VMware Virtual Platform" ]]; then
    exit 0
fi

# Install the VMWare Tools from the Linux ISO.
printf "Installing the VMWare Tools.\n"

# Add the community repository.
printf "@community https://dl-3.alpinelinux.org/alpine/v3.5/community\n@community https://mirror.leaseweb.com/alpine/v3.5/community\n" >> /etc/apk/repositories

# Update the APK cache.
apk update

# Install the Open VMWare Tools.
apk add perl build-base mkinitfs util-linux linux-pam linux-headers
apk add open-vm-tools

# Autostart the open-vm-tools.
rc-update add open-vm-tools default && rc-service open-vm-tools start

# Boosts the available entropy which allows magma to start faster.
apk add haveged

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

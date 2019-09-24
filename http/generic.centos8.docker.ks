# This is a minimal CentOS kickstart designed to create a dockerized environment.
install
keyboard us
rootpw locked
timezone US/Pacific
selinux --enforcing
firewall --disabled
network --bootproto=dhcp --device=link --activate --onboot=on --noipv6 --hostname=centos8.localdomain
reboot
bootloader --location=mbr --append="net.ifnames=0 biosdevname=0 elevator=noop no_timer_check"
lang en_US

# Disk setup
zerombr
clearpart --all --initlabel
part / --size 32768 --fstype ext4

# Package setup
%packages --instLangs=en --nobase
@core
coreutils
bash
yum
vim-minimal
centos-release
less
# Microcode updates don't work in a VM
-microcode_ctl
# Firmware packages aren't needed in a VM
-*firmware
-os-prober
-gettext*
-bind-license
-freetype
iputils
iproute
systemd
rootfiles
-libteam
-teamd
tar
passwd
%end

%post

#echo "locked" | passwd --stdin

%end

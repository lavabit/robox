# This is a minimal CentOS kickstart designed to create a dockerized environment.
# Basic Kickstart Config.
install
keyboard us
lang en_US.UTF-8
rootpw locked
authconfig --enableshadow --passalgo=sha512
timezone US/Pacific
selinux --enforcing
firewall --disabled
network --bootproto=dhcp --device=eth0 --activate --onboot=on --noipv6 --hostname=centos6.localdomain
reboot
bootloader --location=partition

# Disk setup
zerombr
clearpart --all --initlabel
autopart

%packages --nobase
@core
vim-minimal
yum
bash
centos-release
shadow-utils
findutils
iputils
iproute
grub
# Microcode updates don't work in a VM
-microcode_ctl
# Firmware packages aren't needed in a VM
-*firmware
passwd
rootfiles
util-linux-ng
coreutils
authconfig
sudo
%end

%post

#echo "locked" | passwd --stdin

%end

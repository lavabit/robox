install
cdrom

lang en_US.UTF-8
keyboard us
timezone US/Pacific

text
skipx

firstboot --disabled
selinux --enforcing
firewall --enabled --service=ssh

network --device eth0 --bootproto dhcp --noipv6 --hostname=rhel6.localdomain

zerombr
clearpart --all --initlabel
bootloader --location=mbr --append="net.ifnames=0 biosdevname=0 elevator=noop no_timer_check vga=792"
autopart

rootpw locked
authconfig --enableshadow --passalgo=sha512

reboot --eject

%packages --nobase
@core
sudo
libedit
authconfig
openssh-clients
system-config-firewall-base
# Microcode updates don't work in a VM
-microcode_ctl
# Firmware packages aren't needed in a VM
-*firmware
%end

%post

# Duplicate the install media so the DVD can be ejected.
mount /dev/cdrom /mnt/
cp --recursive /mnt/* /media/
umount /mnt/

%end

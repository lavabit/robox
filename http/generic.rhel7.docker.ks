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

network --device eth0 --bootproto dhcp --noipv6 --hostname=rhel7.localdomain

zerombr
clearpart --all --initlabel
bootloader --location=mbr --append="net.ifnames=0 biosdevname=0 elevator=noop no_timer_check"
autopart --nohome

rootpw locked
authconfig --enableshadow --passalgo=sha512

reboot --eject

%packages --instLangs=en --nobase
@core
authconfig
sudo
# Microcode updates don't work in a VM
-microcode_ctl
# Firmware packages aren't needed in a VM
-*firmware
-fprintd-pam
-intltool
%end

%post

# Duplicate the install media so the DVD can be ejected.
mount /dev/cdrom /mnt/
cp --recursive /mnt/* /media/
umount /mnt/

%end

# This is a minimal Rocky kickstart designed to create a dockerized environment.
install

keyboard us
rootpw locked
timezone US/Pacific

text
skipx

firstboot --disabled

selinux --enforcing
firewall --disabled
network --bootproto=dhcp --device=link --activate --onboot=on --noipv6 --hostname=rocky9.localdomain
reboot
bootloader --location=mbr --append="net.ifnames=0 biosdevname=0 no_timer_check"
lang en_US

# Disk setup
zerombr
clearpart --all --initlabel
autopart --nohome

# repo --name=BaseOS
url --url=https://dfw.mirror.rackspace.com/rocky/8.6/BaseOS/x86_64/os/

# Package setup
%packages --instLangs=en_US.utf8
@core
authconfig
sudo
-fprintd-pam
-intltool
-iwl*-firmware
-microcode_ctl
%end

%post

#echo "locked" | passwd --stdin

%end

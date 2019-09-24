# This is a minimal CentOS kickstart designed to create a dockerized environment.
install
keyboard us
rootpw locked
timezone US/Pacific
selinux --enforcing
firewall --disabled
network --bootproto=dhcp --device=link --activate --onboot=on --noipv6 --hostname=centos8.localdomain
reboot
bootloader --location=mbr --append="net.ifnames=0 biosdevname=0 no_timer_check"
lang en_US

# Disk setup
zerombr
clearpart --all --initlabel
part / --size 32768 --fstype ext4

repo --name=BaseOS
url --url=http://mirror.centos.org/centos-8/8.0.1905/BaseOS/x86_64/os/

# Package setup
%packages --instLangs=en
@core
coreutils
bash
dnf
vim-minimal
centos-release
less
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

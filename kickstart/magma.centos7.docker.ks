# This is a minimal CentOS kickstart designed to create a dockerized build environment capable of compiling the magma mail daemon.
# Basic Kickstart Config.
url --url="https://mirrors.kernel.org/centos/7/os/x86_64/"
install
keyboard us
rootpw locked
timezone US/Pacific
selinux --enforcing
firewall --disabled
network --bootproto=dhcp --device=link --activate --onboot=on --noipv6 --hostname=magma.builder
reboot
bootloader --location=partition
lang en_US

# Repositories to use
repo --name="CentOS" --baseurl=https://mirrors.kernel.org/centos/7/os/x86_64/ --cost=100
repo --name="Updates" --baseurl=https://mirrors.kernel.org/centos/7/updates/x86_64/ --cost=100

# Disk setup
zerombr
clearpart --all --initlabel
part / --size 32768 --fstype ext4

# Package setup
%packages --instLangs=en
@core
coreutils
bind-utils
bash
yum
vim-minimal
centos-release
less
-kernel*
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
yum-utils
yum-plugin-ovl
%end

%post

#echo "locked" | passwd --stdin 

%end

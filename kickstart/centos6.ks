# This is a minimal CentOS kickstart designed to create a dockerized build environment capable of compiling the magma mail daemon.
# Basic Kickstart Config.
url --url="https://mirrors.kernel.org/centos/6/os/x86_64/"
install
keyboard us
lang en_US.UTF-8
rootpw locked
authconfig --enableshadow --passalgo=sha512
timezone --isUtc Etc/UTC
selinux --enforcing
firewall --disabled
network --bootproto=dhcp --device=eth0 --activate --onboot=on --noipv6 --hostname=magma.builder
reboot
bootloader --location=partition

# Repositories to use
repo --name="CentOS" --baseurl=https://mirrors.kernel.org/centos/6/os/x86_64/ --cost=100
repo --name="Updates" --baseurl=https://mirrors.kernel.org/centos/6/updates/x86_64/ --cost=100

# Disk setup
zerombr
clearpart --all --initlabel
part / --size 32768 --fstype ext4

%packages
@core
vim-minimal
yum
bash
bind-utils
centos-release
shadow-utils
findutils
iputils
iproute
grub
-*-firmware
passwd
rootfiles
util-linux-ng
yum-plugin-ovl
coreutils
authconfig
sudo
%end

%post --log=/tmp/anaconda-post.log

echo "locked" | passwd --stdin 

%end

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

network --device eth0 --bootproto dhcp --noipv6 --hostname=centos6.localdomain

zerombr
clearpart --all --initlabel
bootloader --location=mbr --append="no_timer_check console=tty0 console=ttyS0,115200n8 net.ifnames=0 biosdevname=0 elevator=noop vga=792" 
autopart

rootpw vagrant
authconfig --enableshadow --passalgo=sha512

reboot --eject

%packages --nobase
@core
authconfig
system-config-firewall-base
sudo
# Microcode updates don't work in a VM
-microcode_ctl
# Firmware packages aren't needed in a VM
-*firmware
%end

%post

# Create the vagrant user account.
/usr/sbin/useradd vagrant
echo "vagrant" | passwd --stdin vagrant

# Make the future vagrant user a sudo master.
sed -i "s/^.*requiretty/#Defaults requiretty/" /etc/sudoers
echo "vagrant        ALL=(ALL)       NOPASSWD: ALL" >> /etc/sudoers.d/vagrant
chmod 0440 /etc/sudoers.d/vagrant

VIRT=`dmesg | grep "Hypervisor detected" | awk -F': ' '{print $2}'`
if [[ $VIRT == "Microsoft HyperV" || $VIRT == "Microsoft Hyper-V" ]]; then
    yum --assumeyes install eject hyperv-daemons
    chkconfig hypervvssd on
    chkconfig hypervkvpd on
#    eject /dev/cdrom
fi

%end

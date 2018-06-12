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
bootloader --location=mbr
autopart

rootpw vagrant
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
%end

%post

# Create the vagrant user account.
/usr/sbin/useradd vagrant
echo "vagrant" | passwd --stdin vagrant

# Make the future vagrant user a sudo master.
sed -i "s/^.*requiretty/#Defaults requiretty/" /etc/sudoers
echo "vagrant        ALL=(ALL)       NOPASSWD: ALL" >> /etc/sudoers.d/vagrant
chmod 0440 /etc/sudoers.d/vagrant

# Duplicate the install media so the DVD can be ejected.
mount /dev/cdrom /mnt/
cp --recursive /mnt/* /media/
umount /mnt/

VIRT=`dmesg | grep "Hypervisor detected" | awk -F': ' '{print $2}'`
if [[ $VIRT == "Microsoft HyperV" || $VIRT == "Microsoft Hyper-V" ]]; then
    if [ ! -f /media/media.repo ]; then
      mount /dev/cdrom /media
    fi

    cp /media/media.repo /etc/yum.repos.d/media.repo
    printf "enabled=1\n" >> /etc/yum.repos.d/media.repo
    printf "baseurl=file:///media/\n" >> /etc/yum.repos.d/media.repo

    yum --assumeyes install eject hyperv-daemons
    systemctl enable hypervkvpd.service
    systemctl enable hypervvssd.service

    rm --force /etc/yum.repos.d/media.repo
fi

%end

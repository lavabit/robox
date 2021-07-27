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

network --device eth0 --bootproto dhcp --noipv6 --hostname=rhel8.localdomain

zerombr
clearpart --all --initlabel
bootloader --location=mbr --append="net.ifnames=0 biosdevname=0 no_timer_check"
autopart --nohome

rootpw vagrant
authconfig --enableshadow --passalgo=sha512

reboot --eject

%packages --instLangs=en
@core
authconfig
rsync
sudo
-fprintd-pam
-intltool
-iwl*-firmware
-microcode_ctl
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
cp --recursive /mnt/BaseOS/ /media/ && cp --recursive /mnt/AppStream/ /media/

VIRT=`dmesg | grep "Hypervisor detected" | awk -F': ' '{print $2}'`
if [[ $VIRT == "Microsoft HyperV" || $VIRT == "Microsoft Hyper-V" ]]; then

  HYPERV_RPMS=`find /mnt/AppStream/Packages/ -iname "hyperv*rpm" -or -iname "cifs-utils*rpm"`

  dnf --assumeyes install $HYPERV_RPMS

  systemctl enable hypervkvpd.service
  systemctl enable hypervvssd.service

fi

%end

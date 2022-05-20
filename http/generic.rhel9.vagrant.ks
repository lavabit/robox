text
reboot --eject
lang en_US.UTF-8
keyboard us
timezone US/Pacific
rootpw --plaintext vagrant
user --name=vagrant --password=vagrant --plaintext

zerombr
clearpart --all --initlabel
part /boot --fstype="xfs" --size=1024 --label=boot
part pv.01 --fstype="lvmpv" --grow
volgroup rhel --pesize=4096 pv.01
logvol swap --fstype="swap" --size=2048 --name=swap --vgname=rhel
logvol / --fstype="xfs" --percent=100 --label="root" --name=root --vgname=rhel

firewall --enabled --service=ssh
authconfig --enableshadow --passalgo=sha512
network --device eth0 --bootproto dhcp --noipv6 --hostname=rhel9.localdomain
bootloader --timeout=1 --append="net.ifnames=0 biosdevname=0 no_timer_check vga=792 nomodeset text"

%packages
@core
authconfig
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

sed -i -e "s/.*PermitRootLogin.*/PermitRootLogin yes/g" /etc/ssh/sshd_config
sed -i -e "s/.*PasswordAuthentication.*/PasswordAuthentication yes/g" /etc/ssh/sshd_config

cat <<-EOF > /etc/udev/rules.d/60-scheduler.rules
# Set the default scheduler for various device types and avoid the buggy bfq scheduler.
ACTION=="add|change", KERNEL=="sd[a-z]|sg[a-z]|vd[a-z]|hd[a-z]|xvd[a-z]|dm-*|mmcblk[0-9]*|nvme[0-9]*", ATTR{queue/scheduler}="mq-deadline"
EOF

%end

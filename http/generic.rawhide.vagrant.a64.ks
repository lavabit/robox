text
reboot --eject
lang en_US.UTF-8
keyboard us
timezone US/Pacific
rootpw --plaintext vagrant
user --name=vagrant --password=vagrant --plaintext

#zerombr
#clearpart --all
#part /boot/efi --fstype=efi --size=128 --label=boot_efi
#part /boot --fstype="xfs" --size=1024 --label=boot
#part fedora_pv --fstype="lvmpv" --grow --label=fedora_pv
#volgroup fedora --pesize=4096 fedora_pv
#logvol swap --fstype="swap" --size=2048 --name=swap --vgname=fedora
#logvol / --fstype="xfs" --percent=100 --label="root" --name=root --vgname=fedora

zerombr
clearpart --all --initlabel
autopart --type=lvm



firewall --enabled --service=ssh
network --activate --device eth0 --bootproto dhcp --noipv6 --hostname=fedora-rawhide.localdomain --nameserver=1.1.1.1 --nameserver=4.2.2.1
bootloader --timeout=1 --append="net.ifnames=0 biosdevname=0"

#### Prod Repo
url --url=https://dl.fedoraproject.org/pub/fedora/linux/development/rawhide/Server/aarch64/os/
# url --url=https://mirrors.edge.kernel.org/fedora/development/rawhide/Everything/aarch64/os/

%packages
@core
net-tools
sudo
-mcelog
-microcode_ctl
-smartmontools
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
    dnf --assumeyes install hyperv-daemons
    systemctl enable hypervvssd.service
    systemctl enable hypervkvpd.service
fi

sed -i -e "s/.*PermitRootLogin.*/PermitRootLogin yes/g" /etc/ssh/sshd_config
sed -i -e "s/.*PasswordAuthentication.*/PasswordAuthentication yes/g" /etc/ssh/sshd_config

cat <<-EOF > /etc/udev/rules.d/60-scheduler.rules
# Set the default scheduler for various device types and avoid the buggy bfq scheduler.
ACTION=="add|change", KERNEL=="sd[a-z]|sg[a-z]|vd[a-z]|hd[a-z]|xvd[a-z]|dm-*|mmcblk[0-9]*|nvme[0-9]*", ATTR{queue/scheduler}="mq-deadline"
EOF

%end

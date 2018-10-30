install
text
reboot --eject
lang en_US.UTF-8
keyboard us
timezone US/Pacific
rootpw --plaintext vagrant
user --name=vagrant --password=vagrant --plaintext
zerombr
autopart --type=plain --nohome
clearpart --all --initlabel
firewall --enabled --service=ssh
authconfig --enableshadow --passalgo=sha512
network --device eth0 --bootproto dhcp --noipv6 --hostname=fedora29.localdomain
bootloader --timeout=1 --append="net.ifnames=0 biosdevname=0 elevator=noop no_timer_check vga=normal nomodeset text"

# When this release is no longer available from mirrors, enable the archive url.
url --url=https://dl.fedoraproject.org/pub/fedora/linux/releases/29/Server/x86_64/os/
# url --url=https://mirrors.kernel.org/fedora/releases/29/Everything/x86_64/os/
# url --url=https://archives.fedoraproject.org/pub/archive/fedora/linux/releases/29/Everything/x86_64/os/

%packages
net-tools
@core
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
    dnf --assumeyes install eject hyperv-daemons
    systemctl enable hypervvssd.service
    systemctl enable hypervkvpd.service
    sync; eject -m /dev/cdrom
    # umount --force --lazy --detach-loop /dev/sr0
    echo 1 > /proc/sys/kernel/sysrq
    echo b > /proc/sysrq-trigger
fi

%end

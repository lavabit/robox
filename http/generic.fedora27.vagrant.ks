install
text
reboot --eject
url --url=https://archives.fedoraproject.org/pub/archive/fedora/linux/releases/27/Everything/x86_64/os/
lang en_US.UTF-8
keyboard us
timezone US/Pacific
rootpw --plaintext vagrant
user --name=vagrant --password=vagrant --plaintext
zerombr
autopart --type=plain --nohome
clearpart --all --initlabel
bootloader --timeout=1 --append="net.ifnames=0 biosdevname=0 elevator=noop no_timer_check vga=792"
firewall --enabled --service=ssh
authconfig --enableshadow --passalgo=sha512

%packages
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
    dnf --assumeyes install hyperv-daemons
    systemctl enable hypervvssd.service
    systemctl enable hypervkvpd.service
fi

%end

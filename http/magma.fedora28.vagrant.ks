install
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
volgroup fedora --pesize=4096 pv.01
logvol swap --fstype="swap" --size=2048 --name=swap --vgname=fedora
logvol / --fstype="xfs" --percent=100 --label="root" --name=root --vgname=fedora

firewall --enabled --service=ssh --port=6000:tcp,6050:tcp,7000:tcp,7050:tcp,7500:tcp,7501:tcp,7550:tcp,7551:tcp,8000:tcp,8050:tcp,8500:tcp,8550:tcp,9000:tcp,9050:tcp,9500:tcp,9550:tcp,10000:tcp,10050:tcp,10500:tcp,10550:tcp
authconfig --enableshadow --passalgo=sha512

# Hyper-V builds are having trouble with the default video driver. Since this is a
# command line driven system, we force the kernel to use the VGA driver at a
# resolution of 1024x768.
bootloader --timeout=1 --append="net.ifnames=0 biosdevname=0 elevator=noop no_timer_check vga=792"

url --url=https://archives.fedoraproject.org/pub/archive/fedora/linux/releases/28/Everything/x86_64/os/

%packages
net-tools
@core
-mcelog
-usbutils
-microcode_ctl
-smartmontools
-plymouth
-plymouth-core-libs
-plymouth-scripts
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

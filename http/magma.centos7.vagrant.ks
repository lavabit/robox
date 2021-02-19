install
cdrom

lang en_US.UTF-8
keyboard us
timezone US/Pacific

text
skipx

firstboot --disabled
selinux --enforcing
firewall --enabled --service=ssh --port=6000:tcp,6050:tcp,7000:tcp,7050:tcp,7500:tcp,7501:tcp,7550:tcp,7551:tcp,8000:tcp,8050:tcp,8500:tcp,8550:tcp,9000:tcp,9050:tcp,9500:tcp,9550:tcp,10000:tcp,10050:tcp,10500:tcp,10550:tcp

network --device eth0 --bootproto dhcp --noipv6 --hostname=magma.builder

zerombr
clearpart --all --initlabel
autopart --nohome

bootloader --location=mbr --append="net.ifnames=0 biosdevname=0 elevator=noop no_timer_check"

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
-fprintd-pam
-intltool
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
  yum --assumeyes install hyperv-daemons cifs-utils
  systemctl enable hypervvssd.service
  systemctl enable hypervkvpd.service
fi

%end

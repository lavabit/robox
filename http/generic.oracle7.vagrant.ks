install

lang en_US.UTF-8
keyboard us
timezone US/Pacific

text
skipx

firstboot --disabled
selinux --enforcing
firewall --enabled --service=ssh

network --device eth0 --bootproto dhcp --noipv6 --hostname=oracle7.localdomain

zerombr
clearpart --all --initlabel
bootloader --location=mbr --append="net.ifnames=0 biosdevname=0 elevator=noop no_timer_check"
autopart --nohome

rootpw vagrant
authconfig --enableshadow --passalgo=sha512

url --url=https://yum.oracle.com/repo/OracleLinux/OL7/latest/x86_64/

reboot --eject

%packages --instLangs=en --nobase
@core
authconfig
sudo
# Microcode updates don't work in a VM
#-microcode_ctl
# Firmware packages aren't needed in a VM
#-*firmware
kernel-abi-whitelists
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

  # Change the default boot kernel to the base model, otherwise the Hyper-V daemons will fail to start.
  KERN=`grep menuentry /boot/grub2/grub.cfg  | awk -F"'" '{print $2}' | grep -v -E "^$|Unbreakable|rescue"`
  sed -i -e "s/saved_entry=.*/saved_entry=$KERN/g" /boot/grub2/grubenv
fi

%end

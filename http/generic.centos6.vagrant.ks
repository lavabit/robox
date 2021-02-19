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
bootloader --location=mbr --append="net.ifnames=0 biosdevname=0 elevator=noop no_timer_check vga=792"
autopart


rootpw vagrant
authconfig --enableshadow --passalgo=sha512

reboot --eject

%packages --nobase
@core
sudo
curl
authconfig
system-config-firewall-base
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
    cd /root/
    curl -4 --silent --retry 10 --retry-delay 10 --remote-name https://vault.centos.org/6.10/os/x86_64/Packages/hyperv-daemons-0-0.17.20150108git.el6.x86_64.rpm
    curl -4 --silent --retry 10 --retry-delay 10 --remote-name https://vault.centos.org/6.10/os/x86_64/Packages/hyperv-daemons-license-0-0.17.20150108git.el6.noarch.rpm
    curl -4 --silent --retry 10 --retry-delay 10 --remote-name https://vault.centos.org/6.10/os/x86_64/Packages/hypervfcopyd-0-0.17.20150108git.el6.x86_64.rpm
    curl -4 --silent --retry 10 --retry-delay 10 --remote-name https://vault.centos.org/6.10/os/x86_64/Packages/hypervkvpd-0-0.17.20150108git.el6.x86_64.rpm
    curl -4 --silent --retry 10 --retry-delay 10 --remote-name https://vault.centos.org/6.10/os/x86_64/Packages/hypervvssd-0-0.17.20150108git.el6.x86_64.rpm
    (printf "d52f20e4b3b2c477a437bc572bf402ea0297f979e87a02b48f10da48f367e3bb  hyperv-daemons-0-0.17.20150108git.el6.x86_64.rpm\n" | sha256sum -c) || exit 1
    (printf "cf2a69cd781270941b63802004b516bbf3515ed111b243ad489aa9c16424794c  hyperv-daemons-license-0-0.17.20150108git.el6.noarch.rpm\n" | sha256sum -c) || exit 1
    (printf "96373df61de41dce587462282d14158f04ac4973ec2f8014de99d7f5e779f08a  hypervfcopyd-0-0.17.20150108git.el6.x86_64.rpm\n" | sha256sum -c) || exit 1
    (printf "cd1889b3a5b33e1a3a3c4055f09388a958989d4971677a889a19a5ea12b65ffb  hypervkvpd-0-0.17.20150108git.el6.x86_64.rpm\n" | sha256sum -c) || exit 1
    (printf "91951ccb4ed9bbcda1ac0776e36183eb90c1ca24efcaf02ba0569d0287ebfe74  hypervvssd-0-0.17.20150108git.el6.x86_64.rpm\n" | sha256sum -c) || exit 1
    yum --assumeyes --disablerepo=* install hyperv-daemons-0-0.17.20150108git.el6.x86_64.rpm hyperv-daemons-license-0-0.17.20150108git.el6.noarch.rpm hypervfcopyd-0-0.17.20150108git.el6.x86_64.rpm hypervkvpd-0-0.17.20150108git.el6.x86_64.rpm hypervvssd-0-0.17.20150108git.el6.x86_64.rpm
    rm --force hyperv-daemons-0-0.17.20150108git.el6.x86_64.rpm hyperv-daemons-license-0-0.17.20150108git.el6.noarch.rpm hypervfcopyd-0-0.17.20150108git.el6.x86_64.rpm hypervkvpd-0-0.17.20150108git.el6.x86_64.rpm hypervvssd-0-0.17.20150108git.el6.x86_64.rpm
    chkconfig hypervvssd on
    chkconfig hypervkvpd on
fi

%end

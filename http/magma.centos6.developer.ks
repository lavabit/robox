install
url --url=https://vault.centos.org/6.10/os/x86_64/
repo --name=debug --baseurl=http://debuginfo.centos.org/6/x86_64/
repo --name=extras --baseurl=https://vault.centos.org/6.10/extras/x86_64/
repo --name=updates --baseurl=https://vault.centos.org/6.10/updates/x86_64/
repo --name=epel --baseurl=https://archives.fedoraproject.org/pub/archive/epel/6/x86_64/
repo --name=epel-debuginfo --baseurl=https://archives.fedoraproject.org/pub/archive/epel/6/SRPMS/
lang en_US.UTF-8
keyboard us
timezone US/Pacific
firstboot --disabled
selinux --enforcing
firewall --enabled --service=ssh --port=6000:tcp,6050:tcp,7000:tcp,7050:tcp,7500:tcp,7501:tcp,7550:tcp,7551:tcp,8000:tcp,8050:tcp,8500:tcp,8550:tcp,9000:tcp,9050:tcp,9500:tcp,9550:tcp,10000:tcp,10050:tcp,10500:tcp,10550:tcp
network --device eth0 --bootproto dhcp --noipv6 --hostname=magma.local
zerombr
clearpart --all --initlabel
bootloader --append="net.ifnames=0 biosdevname=0 elevator=noop no_timer_check vga=792"
autopart
rootpw magma
authconfig --enableshadow --passalgo=sha512
reboot --eject

%packages
@base

@basic-desktop
@general-desktop

@mysql
@eclipse
@debugging
@development
@mysql-client
@network-tools
@additional-devel
@desktop-debugging
@server-platform-devel
@desktop-platform-devel

@security-tools
@console-internet
@internet-browser
@internet-applications
%end

%post

# Create the magma user account.
/usr/sbin/useradd magma
echo "magma" | passwd --stdin magma

# Make the future magma user a sudo master.
sed -i "s/^.*requiretty/#Defaults requiretty/" /etc/sudoers
echo "magma        ALL=(ALL)       NOPASSWD: ALL" >> /etc/sudoers.d/magma
chmod 0440 /etc/sudoers.d/magma

VIRT=`dmesg | grep "Hypervisor detected" | awk -F': ' '{print $2}'`
if [[ $VIRT == "Microsoft HyperV" || $VIRT == "Microsoft Hyper-V" ]]; then
    yum --assumeyes install hyperv-daemons
    chkconfig hypervvssd on
    chkconfig hypervkvpd on
fi

%end

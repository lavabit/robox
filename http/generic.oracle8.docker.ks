install
reboot --eject
lang en_US.UTF-8
keyboard us
timezone US/Pacific

text
skipx

firstboot --disabled
selinux --enforcing
firewall --enabled --service=ssh

network --device eth0 --bootproto dhcp --noipv6 --hostname=oracle8.localdomain

zerombr
clearpart --all --initlabel
bootloader --location=mbr --append="net.ifnames=0 biosdevname=0 no_timer_check"
autopart --nohome

rootpw locked
authconfig --enableshadow --passalgo=sha512

url --url=https://yum.oracle.com/repo/OracleLinux/OL8/baseos/latest/x86_64/
repo --name=appstream --baseurl=https://yum.oracle.com/repo/OracleLinux/OL8/appstream/x86_64/

%packages --instLangs=en
@core
authconfig
sudo
-fprintd-pam
-intltool
-iwl*-firmware
-microcode_ctl
%end

%post

#echo "locked" | passwd --stdin

%end

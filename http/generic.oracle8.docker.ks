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

network --device eth0 --bootproto dhcp --noipv6 --hostname=oracle8.localdomain

zerombr
clearpart --all --initlabel
bootloader --location=mbr --append="net.ifnames=0 biosdevname=0 no_timer_check"
autopart --nohome

rootpw locked
authconfig --enableshadow --passalgo=sha512

reboot --eject

%packages --instLangs=en
@core
authconfig
sudo
%end

%post

#echo "locked" | passwd --stdin

%end

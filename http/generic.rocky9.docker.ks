text
reboot --eject
lang en_US.UTF-8
keyboard us
timezone US/Pacific
rootpw --plaintext locked

zerombr
clearpart --all --initlabel
autopart --type=lvm --nohome

firewall --enabled --service=ssh
network --device eth0 --bootproto dhcp --noipv6 --hostname=rocky9.localdomain
bootloader --timeout=1 --append="net.ifnames=0 biosdevname=0 no_timer_check vga=792 nomodeset text"

# repo --name=BaseOS
url --url=https://ftp5.gwdg.de/pub/linux/rocky/9.2/BaseOS/x86_64/os/

%packages
@core
sudo
authconfig
-fprintd-pam
-intltool
-iwl*-firmware
-microcode_ctl
%end

%post

sed -i -e "s/.*PermitRootLogin.*/PermitRootLogin yes/g" /etc/ssh/sshd_config
sed -i -e "s/.*PasswordAuthentication.*/PasswordAuthentication yes/g" /etc/ssh/sshd_config

cat <<-EOF > /etc/udev/rules.d/60-scheduler.rules
# Set the default scheduler for various device types and avoid the buggy bfq scheduler.
ACTION=="add|change", KERNEL=="sd[a-z]|sg[a-z]|vd[a-z]|hd[a-z]|xvd[a-z]|dm-*|mmcblk[0-9]*|nvme[0-9]*", ATTR{queue/scheduler}="mq-deadline"
EOF

%end


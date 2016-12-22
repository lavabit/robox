#!/bin/bash -x

# This script grabs several files off the web, but doesn't verigy the signature
# for any of them. The best I could do, with little effort, was have them use https.

fdisk /dev/vda <<EOF
o
n
p
1


a
w
EOF
sync

#mkfs.ext4 -E lazy_itable_init=0,lazy_journal_init=0 /dev/vda1
mkfs.ext4 /dev/vda1
mount -o relatime,discard /dev/vda1 /mnt/gentoo

ARCH=""
if [ "x$(uname -m)" == "xx86_64" ];then
    ARCH="x86_64"
else
    ARCH="x86_32"
fi

FILE=""
if [ "${ARCH}" == "x86_64" ];then
    FILE=$(wget -q https://mirrors.kernel.org/gentoo/releases/amd64/autobuilds/current-stage3-amd64-systemd/ -O - | grep -o -e "stage3-amd64-systemd-\w*.tar.bz2" | uniq)
    wget -q https://mirrors.kernel.org/gentoo/releases/amd64/autobuilds/current-stage3-amd64-systemd/$FILE -O /mnt/gentoo/stage.tar.bz2 || exit 1
else
    FILE=$(wget -q https://mirrors.kernel.org/gentoo/releases/x86/autobuilds/current-stage3-i686-systemd/ -O - | grep -o -e "stage3-i686-systemd-\w*.tar.bz2" | uniq)
    wget -q https://mirrors.kernel.org/gentoo/releases/x86/autobuilds/current-stage3-i686-systemd/$FILE -O /mnt/gentoo/stage.tar.bz2 || exit 1
fi

tar -C /mnt/gentoo -jxpf /mnt/gentoo/stage.tar.bz2
rm -f /mnt/gentoo/stage.tar.bz2
wget -q https://mirrors.kernel.org/gentoo/snapshots/portage-latest.tar.bz2 -O /mnt/gentoo/portage.tar.bz2
tar -C /mnt/gentoo/usr/ -jxf /mnt/gentoo/portage.tar.bz2
rm -f /mnt/gentoo/portage.tar.bz2
sync

mount -t proc proc /mnt/gentoo/proc
mount --rbind /dev /mnt/gentoo/dev
mount --rbind /sys /mnt/gentoo/sys

cp -L /etc/resolv.conf /mnt/gentoo/etc/

chroot /mnt/gentoo /bin/bash -ex <<'EOF'
emerge-webrsync
ln -snf /usr/share/zoneinfo/UTC /etc/localtime
echo UTC > /etc/timezone
EOF

chroot /mnt/gentoo /bin/bash -ex <<'EOF'
cat > /etc/fstab <<'DATA'
# <fs>		<mount>	<type>	<opts>		<dump/pass>
/dev/vda1    /	   ext4	  defaults,relatime,errors=panic		0 1
DATA
EOF

chroot /mnt/gentoo /bin/bash -ex <<'EOF'
cat > /etc/udev/rules.d/80-hotplug-cpu-mem.rules <<'DATA'
# Hotplug physical CPU
SUBSYSTEM=="cpu", ACTION=="add", TEST=="online", ATTR{online}=="0", ATTR{online}="1"

# Hotplug physical memory
SUBSYSTEM=="memory", ACTION=="add", TEST=="state", ATTR{state}=="offline", ATTR{state}="online"
DATA
EOF

chroot /mnt/gentoo /bin/bash -ex <<EOF
GRUB_PLATFORMS="pc" USE="-doc -fonts -themes" emerge --quiet y --nospinner ">=sys-boot/grub-2.0" net-misc/curl
ACCEPT_KEYWORDS="~amd64" emerge --quiet y --nospinner dracut

mkdir /tmp/kernel
if [ "${ARCH}" == "x86_64" ];then
  curl -Ls https://www.archlinux.org/packages/core/x86_64/linux/download/ | tar --exclude=etc/mkinitcpio.d/ -C /tmp/kernel -Jxf -
else
  curl -Ls https://www.archlinux.org/packages/core/i686/linux/download/ | tar --exclude=etc/mkinitcpio.d/ -C /tmp/kernel -Jxf -
fi

ln -sf /dev/null /etc/udev/rules.d/80-net-setup-link.rules
ln -sf /dev/null /etc/udev/rules.d/80-net-name-slot.rules
ln -sf /dev/null /etc/systemd/network/99-default.link
mkdir -p /boot/grub
grub-install /dev/vda

for f in .BUILDINFO .INSTALL .MTREE .PKGINFO; do echo /\$f; rm -f /\$f; done
mv /tmp/kernel/usr/lib/modules /lib/
rm -rf /lib/modules/*extra*
mv /tmp/kernel/boot/vmlin* /boot/vmlinuz-\$(ls -1 /lib/modules/)
dracut --fstab --gzip --filesystems ext4 /boot/initramfs-\$(ls -1 /lib/modules).img \$(ls -1 /lib/modules)
sed -i 's|#GRUB_DISABLE_LINUX_UUID=true|GRUB_DISABLE_LINUX_UUID=true|g' /etc/default/grub
sed -i 's|.*GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT="consoleblank=0 net.ifnames=0 biosdevname=0"|g' /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

sed -i 's/\#Pub/Pub/g' /etc/ssh/sshd_config
sed -i 's|.*PermitRootLogin.*|PermitRootLogin yes|g' /etc/ssh/sshd_config
sed 's|.*UseDNS.*|UseDNS no|g' -i /etc/ssh/sshd_config
sed -i 's|GSSAPIAuthentication yes|GSSAPIAuthentication no|g'  /etc/ssh/sshd_config
sed -i 's|PasswordAuthentication no|PasswordAuthentication yes|g' /etc/ssh/sshd_config


systemd-firstboot --setup-machine-id
systemctl enable sshd.service
systemctl enable systemd-networkd.service
systemctl enable systemd-resolved.service

cat <<REOF > /etc/systemd/network/dhcp.network
[Match]
Name=e*

[Network]
DHCP=yes

[DHCPv4]
UseHostname=false
REOF
EOF

rm -rf /mnt/gentoo/tmp/*
rm -rf /mnt/gentoo/var/log/*
rm -rf /mnt/gentoo/var/tmp/*

cat /proc/mounts
for m in dev/mqueue dev/pts dev/shm dev sys/kernel/security sys/kernel/debug sys/kernel/config sys/fs/fuse/connections sys proc; do
  umount /mnt/gentoo/$m;
done
umount /mnt/gentoo/
cat /proc/mounts
sync

service sshd stop
nohup /bin/bash -c 'shutdown -r now &'
exit 0

#!/bin/bash -xe

echo 'Creating File System Table'
cat <<-EOF > /etc/fstab
/dev/vda1       /boot/EFI 	vfat	      noauto,noatime 1 2
/dev/vda2       /boot       ext4        defaults   0 0
/dev/vda3       none        swap        defaults   0 0
/dev/vda4       /           ext4        defaults   0 0

/dev/cdrom      /mnt/cdrom  auto        noauto,ro  0 0
EOF

echo 'Creating Portage Makefile'
cat <<-EOF > /etc/portage/make.conf
CHOST="aarch64-gentoo-linux-gnu"
CFLAGS="-mtune=generic -O2 -pipe"
CXXFLAGS="\${CFLAGS}"
MAKEOPTS="-j64"
EMERGE_DEFAULT_OPTS="-j64 --with-bdeps=y --quiet-build=y --complete-graph"
FEATURES="\${FEATURES} parallel-fetch"
USE="nls alsa usb unicode openssl cpudetection systemd"
GRUB_PLATFORMS="efi-64"
PORTDIR="/usr/portage"
DISTDIR="${PORTDIR}/distfiles"
PKGDIR="${PORTDIR}/packages"
SYMLINK_LIB="no"
EOF

echo 'Configuring Locale'
cat <<-EOF > /etc/env.d/02locale
LANG="en_US.UTF-8"
LC_COLLATE="POSIX"
EOF

cat <<-EOF > /etc/locale.gen
en_US.UTF-8 UTF-8
EOF

echo 'Rebuilding the System Locales'
locale-gen -A -j 60

setfont /usr/share/consolefonts/latarcyrheb-sun16.psfu.gz

echo 'Configuring Timezone'
ln -snf /usr/share/zoneinfo/US/Pacific /etc/localtime
echo 'US/Pacific' > /etc/timezone

# This distribution does not like flags described in single files
# all 'package.*', except 'package.keywords', should be directories.
mkdir -p "/etc/portage/package.license"
mkdir -p "/etc/portage/package.use"
mkdir -p "/etc/portage/package.accept_keywords"
mkdir -p "/etc/portage/package.mask"
mkdir -p "/etc/portage/package.unmask"

echo 'Setting Portage Profile'
eselect profile set default/linux/arm64/17.0/systemd

# Dynamically find the current stable profile.
# cd /usr/portage
# profile="`grep stable profiles/profiles.desc | grep -v desktop | grep -v systemd | grep arm64 | awk -F' ' '{print \$2}' | grep -E 'default/linux/arm64/[0-9\.]*\$' | head -1`"
# eselect profile set $profile

echo 'Emerging Dependencies'
emerge --ask=n --autounmask-write=y --autounmask-continue=y sys-kernel/gentoo-kernel-bin sys-boot/grub:2 sys-boot/efibootmgr app-editors/vim app-admin/sudo sys-apps/dmidecode sys-apps/systemd sys-apps/gentoo-systemd-integration sys-apps/dbus

# If necessary, include the Hyper-V modules in the initramfs and then load them at boot.
if [ "$(dmidecode -s system-manufacturer)" == "Microsoft Corporation" ]; then
  echo 'MODULES_HYPERV="hv_vmbus hv_storvsc hv_balloon hv_netvsc hv_utils"' >> /usr/share/genkernel/arch/arm64/modules_load
  echo 'modules="hv_storvsc hv_netvsc hv_vmbus hv_utils hv_balloon"' >> /etc/conf.d/modules
  sed -ri "s/(HWOPTS='.*)'/\1 hyperv'/" /usr/share/genkernel/defaults/initrd.defaults
fi

echo 'Configuring EFI'
mkdir -p /boot/EFI/gentoo
cp /boot/vmlinuz-* /boot/EFI/gentoo/bzImage.efi 
efibootmgr --create --disk /dev/vda --part 1 --label "gentoo" --loader "\EFI\gentoo\bzImage.efi"

echo 'Configuring Grub'
DEVID=`blkid -s UUID -o value /dev/vda4`
printf "\nGRUB_DEVICE_UUID=\"$DEVID\"\n" >> /etc/default/grub
grub-install --efi-directory=/boot/EFI /dev/vda
grub-mkconfig -o /boot/grub/grub.cfg

echo 'Configuring Network Services'
emerge --ask=n --autounmask-write=y --autounmask-continue=y net-wireless/wireless-tools net-misc/dhcpcd net-misc/networkmanager
ln -sf /dev/null /etc/udev/rules.d/80-net-setup-link.rules
ln -sf /dev/null /etc/udev/rules.d/80-net-name-slot.rules
#echo 'config_enp0s3=( "dhcp" )' >> /etc/conf.d/net
#echo 'config_eth0=( "dhcp" )' >> /etc/conf.d/net
#ln -s /etc/init.d/net.lo /etc/init.d/net.eth0
#rc-update add net.eth0 default
cat <<-EOF > /etc/NetworkManager/system-connections/eth0.nmconnection
[connection]
id=eth0
uuid=$(uuidgen)
type=ethernet
autoconnect-priority=-999
interface-name=eth0
timestamp=$(date +%s)

[ethernet]

[ipv4]
method=auto

[ipv6]
addr-gen-mode=eui64
method=auto

[proxy]

EOF
systemctl enable NetworkManager.service

echo 'Configuration SSH'
sed -i -e "s/.*PermitRootLogin.*/PermitRootLogin yes/g" /etc/ssh/sshd_config
sed -i -e "s/.*PasswordAuthentication.*/PasswordAuthentication yes/g" /etc/ssh/sshd_config
#rc-update add sshd default
systemctl enable sshd.service

# Disable the password checks so we can use the default password.
sed -i 's/min=.*/min=1,1,1,1,1/g' /etc/security/passwdqc.conf

echo 'Configuring Users'
useradd vagrant
echo 'root:vagrant' | chpasswd > /dev/null
echo 'vagrant:vagrant' | chpasswd > /dev/null

# If we're running on Hyper-V, setup the daemons.
if [ "$(dmidecode -s system-manufacturer)" == "Microsoft Corporation" ]; then
  echo 'Configuring Hyper-V'
  emerge sys-kernel/gentoo-sources
  cd /usr/src/linux-*-gentoo/tools/hv && make
  install -t /usr/sbin/ hv_fcopy_daemon hv_vss_daemon hv_kvp_daemon

tee /etc/init.d/hv_fcopy_daemon <<-EOF
#!/sbin/openrc-run

name="Hyper-V daemon: hv_fcopy_daemon"
command=/usr/sbin/hv_fcopy_daemon

depend() {
	use clock logger
	need localmount
}
EOF

tee /etc/init.d/hv_kvp_daemon <<-EOF
#!/sbin/openrc-run

name="Hyper-V daemon: hv_kvp_daemon"
command=/usr/sbin/hv_kvp_daemon

depend() {
	use clock logger
	need localmount net
}

start_pre() {
	# Delete the existing store
	rm -rf /var/lib/hyperv
}
EOF

tee /etc/init.d/hv_vss_daemon <<-EOF
#!/sbin/openrc-run

name="Hyper-V daemon: hv_vss_daemon"
command=/usr/sbin/hv_vss_daemon

depend() {
	use clock logger
	need dev
}
EOF

  # Fix the permissions.
  chmod 755 /etc/init.d/hv_fcopy_daemon
  chmod 755 /etc/init.d/hv_kvp_daemon
  chmod 755 /etc/init.d/hv_vss_daemon

  # Add the Hyper-V daemons to the default runlevel.
  rc-update add hv_fcopy_daemon default
  rc-update add hv_kvp_daemon default
  rc-update add hv_vss_daemon default

# Preserve this configuration in case we ever create a systemd version of Gentoo.
#   mkdir -p /usr/lib/systemd/system
# tee /usr/lib/systemd/system/hv_fcopy_daemon.service <<-EOF
# [Unit]
# Description=Hyper-V File Copy Protocol Daemon
# ConditionVirtualization=microsoft
#
# [Service]
# Type=simple
# ExecStart=/usr/sbin/hv_fcopy_daemon -n
# Restart=always
# RestartSec=3
#
# [Install]
# WantedBy=multi-user.target
# EOF
#
# tee /usr/lib/systemd/system/hv_vss_daemon.service <<-EOF
# [Unit]
# Description=Hyper-V VSS Daemon
# ConditionVirtualization=microsoft
#
# [Service]
# Type=simple
# ExecStart=/usr/sbin/hv_vss_daemon -n
# Restart=always
# RestartSec=3
#
# [Install]
# WantedBy=multi-user.target
# EOF
#
# tee /usr/lib/systemd/system/hv_kvp_daemon.service <<-EOF
# [Unit]
# Description=Hyper-V Key Value Pair Daemon
# ConditionVirtualization=microsoft
# Wants=network-online.target
# After=network.target network-online.target
#
# [Service]
# Type=simple
# ExecStart=/usr/sbin/hv_kvp_daemon -n
# Restart=always
# RestartSec=3
#
# [Install]
# WantedBy=multi-user.target
# EOF
#
#   systemctl enable hv_fcopy_daemon.service
#   systemctl enable hv_vss_daemon.service
#   systemctl enable hv_kvp_daemon.service
fi

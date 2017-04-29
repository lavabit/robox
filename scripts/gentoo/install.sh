#!/bin/bash -ux

# This script grabs several files off the web, but doesn't verify the signature
# for any of them. The best I could do, with little effort, was have them use https.
source /etc/profile
#
# sgdisk -n 1:0:+256M -t 1:8300 -c 1:"linux-boot" \
#        -n 2:0:+32M  -t 2:ef02 -c 2:"bios-boot"  \
#        -n 3:0:+2G   -t 3:8200 -c 3:"swap"       \
#        -n 4:0:0     -t 4:8300 -c 4:"linux-root" \
# -p /dev/sda
#
# sleep 1
#
# # format partitions, mount swap
# mkswap /dev/sda3
# swapon /dev/sda3
# mkfs.ext2 /dev/sda1
# mkfs.ext4 /dev/sda4

# mount other partitions
# mount /dev/sda4 "/mnt/gentoo" && cd "/mnt/gentoo" && mkdir boot && mount /dev/sda1 boot


if [ -e /dev/vda ]; then
  device=/dev/vda
elif [ -e /dev/sda ]; then
  device=/dev/sda
else
  echo "ERROR: There is no disk available for installation" >&2
  exit 1
fi
export device

memory_size_in_kilobytes=$(free | awk '/^Mem:/ { print $2 }')
swap_size_in_kilobytes=$((memory_size_in_kilobytes * 2))
sfdisk "$device" <<EOF
label: dos
size=262144KiB,                    type=83, bootable
size=${swap_size_in_kilobytes}KiB, type=82
                                   type=83
EOF
mkfs.ext4 "${device}1"
mkswap "${device}2"
mkfs.ext4 "${device}3"

mount ${device}3 "/mnt/gentoo" && cd "/mnt/gentoo" && mkdir boot && mount ${device}1 boot


# download the current-stage3-amd64-nomultilib tarball, unpack it, then delete the archive file
tarball=$(wget -q https://mirrors.kernel.org/gentoo/releases/amd64/autobuilds/current-stage3-amd64-nomultilib/ -O - | grep -o -e "stage3-amd64-nomultilib-\w*.tar.bz2" | uniq)
wget --tries=5 -q https://mirrors.kernel.org/gentoo/releases/amd64/autobuilds/current-stage3-amd64-nomultilib/$tarball || exit 1

tar xjpf $tarball && rm -f $tarball
echo "Gentoo image applied."

# prepeare chroot, update env
mount -t proc none "/mnt/gentoo/proc"
mount --rbind /dev "/mnt/gentoo/dev"

# copy nameserver information, save build timestamp
cp /etc/resolv.conf "/mnt/gentoo/etc/"
date -u > "/mnt/gentoo/etc/vagrant_box_build_time"

# retrieve and extract latest portage tarball
chroot "/mnt/gentoo" wget --tries=5 "https://mirrors.kernel.org/gentoo/snapshots/portage-latest.tar.bz2"
chroot "/mnt/gentoo" tar -xjpf portage-latest.tar.bz2 -C /usr
chroot "/mnt/gentoo" rm -rf portage-latest.tar.bz2
chroot "/mnt/gentoo" env-update

# Purge the news.
chroot "/mnt/gentoo" /bin/bash <<EOF
eselect news read --quiet all
eselect news purge
EOF

# bring up network interface and sshd on boot (Alt. for new systemd naming scheme, enp0s3)
#chroot "/mnt/gentoo" /bin/bash <<EOF
#cd /etc/conf.d
#sed -i "s/eth0/enp0s3/" /etc/udhcpd.conf
#echo 'config_enp0s3=( "dhcp" )' >> net
#ln -s net.lo /etc/init.d/net.enp0s3
#rc-update add net.enp0s3 default
#rc-update add sshd default
#EOF

# bring up network interface and sshd on boot (for older systemd naming scheme, eth0)
chroot "/mnt/gentoo" /bin/bash <<EOF
ln -s /dev/null /etc/udev/rules.d/80-net-setup-link.rules
EOF

chroot "/mnt/gentoo" /bin/bash <<EOF
cd /etc/conf.d
echo 'config_eth0=( "dhcp" )' >> net
ln -s net.lo /etc/init.d/net.eth0
rc-update add net.eth0 default
rc-update add sshd default
EOF

# set fstab
cat <<EOF > "/mnt/gentoo/etc/fstab"
# <fs>                  <mountpoint>    <type>          <opts>                   <dump/pass>
/dev/sda1               /boot           ext4            noauto,noatime           1 2
/dev/sda2               none            swap            sw                       0 0
/dev/sda3               /               ext4            noatime                  0 1
none                    /dev/shm        tmpfs           nodev,nosuid,noexec      0 0
EOF

# set make options
cat <<EOF > "/mnt/gentoo/etc/portage/make.conf"
CHOST="i686-pc-linux-gnu"
CFLAGS="-mtune=generic -O0 -pipe"
CXXFLAGS="\${CFLAGS}"
ACCEPT_KEYWORDS="$accept_keywords"
MAKEOPTS="-j8"
EMERGE_DEFAULT_OPTS="-j8 --quiet-build=y"
FEATURES="\${FEATURES} parallel-fetch"
USE="nls cjk unicode"
PYTHON_TARGETS="python2_7 python3_2 python3_3"
USE_PYTHON="3.2 2.7"
# english only
LINGUAS="en"
# for X support if needed
INPUT_DEVICES="evdev"
# Additional portage overlays (space char separated)
PORTDIR_OVERLAY="${PORTDIR_OVERLAY} /usr/local/portage"
# Including /usr/local/portage overlay
source "/usr/local/portage/make.conf"
EOF

# Create an empty portage overlay
mkdir -p "/mnt/gentoo/usr/local/portage"

touch "/mnt/gentoo/usr/local/portage/make.conf"
chown root:portage "/mnt/gentoo/usr/local/portage/make.conf"
chmod g+s "/mnt/gentoo/usr/local/portage/make.conf"
chmod 775 "/mnt/gentoo/usr/local/portage/make.conf"

mkdir -p "/mnt/gentoo/usr/local/portage/profiles"
echo "local_repo" >> "/mnt/gentoo/usr/local/portage/profiles/repo_name"
chown root:portage "/mnt/gentoo/usr/local/portage" "/mnt/gentoo/usr/local/portage/profiles/repo_name"
chmod g+s "/mnt/gentoo/usr/local/portage" "/mnt/gentoo/usr/local/portage/profiles/repo_name"
chmod 775 "/mnt/gentoo/usr/local/portage" "/mnt/gentoo/usr/local/portage/profiles/repo_name"

mkdir -p "/mnt/gentoo/usr/local/portage/metadata"
echo "masters = gentoo" >> "/mnt/gentoo/usr/local/portage/metadata/layout.conf"
chown root:portage "/mnt/gentoo/usr/local/portage/metadata/layout.conf"
chmod g+s "/mnt/gentoo/usr/local/portage/metadata/layout.conf"
chmod 775 "/mnt/gentoo/usr/local/portage/metadata/layout.conf"

# This distribution does not like flags described in single files
# all 'package.*', except 'package.keywords', should be directories.
mkdir -p "/mnt/gentoo/etc/portage/package.license"
mkdir -p "/mnt/gentoo/etc/portage/package.use"
mkdir -p "/mnt/gentoo/etc/portage/package.accept_keywords"
mkdir -p "/mnt/gentoo/etc/portage/package.mask"
mkdir -p "/mnt/gentoo/etc/portage/package.unmask"


# Some forced updates for this system
cat <<EOF >> "/mnt/gentoo/etc/portage/package.unmask/python-2.7"
=dev-lang/python-2.7.5*
EOF

cat <<EOF >> "/mnt/gentoo/etc/portage/package.unmask/pam"
=sys-libs/pam-1.1.6-r2
=sys-libs/pam-1.1.7
EOF

# Setup the timezone
chroot "/mnt/gentoo" ln -snf /usr/share/zoneinfo/US/Pacific /etc/localtime
chroot "/mnt/gentoo" echo US/Pacific > /etc/timezone

# Setup the locale
chroot "/mnt/gentoo" /bin/bash <<EOF
echo LANG=\"en_US.utf8\" > /etc/env.d/02locale
echo LANG_ALL=\"en_US.utf8\" >> /etc/env.d/02locale
echo LANGUAGE=\"en_US.utf8\" >> /etc/env.d/02locale
env-update && source /etc/profile
EOF

chroot "/mnt/gentoo" emerge-webrsync

# add required use flags and keywords
cat <<EOF >> "/mnt/gentoo/etc/portage/package.use/kernel"
sys-kernel/gentoo-sources symlink
sys-kernel/genkernel
EOF

cat <<EOF >> "/mnt/gentoo/etc/portage/package.accept_keywords/kernel"
dev-util/kbuild ~x86 ~amd64
EOF

# get, configure, compile and install the kernel and modules
chroot "/mnt/gentoo" /bin/bash <<EOF
emerge sys-kernel/gentoo-sources sys-kernel/genkernel sys-boot/grub sys-fs/fuse sys-apps/dmidecode gentoolkit
cd /usr/src/linux
# use a default configuration as a starting point
make defconfig
# add settings for VirtualBox kernels to end of .config
cat <<KERNEOF >>/usr/src/linux/.config
# dependencies
CONFIG_EXT4_FS=y
CONFIG_EXT4_USE_FOR_EXT23=y
CONFIG_EXT4_FS_XATTR=y
CONFIG_SMP=y
CONFIG_SCHED_SMT=y
CONFIG_MODULE_UNLOAD=y
CONFIG_DMA_SHARED_BUFFER=y
# for VirtualBox (http://en.gentoo-wiki.com/wiki/Virtualbox_Guest)
CONFIG_HIGH_RES_TIMERS=n
CONFIG_X86_MCE=n
CONFIG_SUSPEND=n
CONFIG_HIBERNATION=n
CONFIG_IDE=n
CONFIG_NO_HZ=y
CONFIG_SMP=y
CONFIG_ACPI=y
CONFIG_PNP=y
CONFIG_ATA=y
CONFIG_SATA_AHCI=y
CONFIG_ATA_SFF=y
CONFIG_ATA_PIIX=y
CONFIG_PCNET32=y
CONFIG_E1000=y
CONFIG_INPUT_MOUSE=y
CONFIG_DRM=y
CONFIG_SND_INTEL8X0=m
# for net fs
CONFIG_AUTOFS4_FS=m
CONFIG_NFS_V2=m
CONFIG_NFS_V3=m
CONFIG_NFS_V4=m
CONFIG_NFSD=m
CONFIG_CIFS=m
CONFIG_CIFS_UPCAL=y
CONFIG_CIFS_XATTR=y
CONFIG_CIFS_DFS_UPCALL=y
# for FUSE fs
CONFIG_FUSE_FS=m
# reduce size
# CONFIG_NR_CPUS is not set
CONFIG_COMPAT_VDSO=n
# propbably nice but not in defaults
CONFIG_MODVERSIONS=y
CONFIG_IKCONFIG_PROC=y
CONFIG_SQUASHFS=y
CONFIG_SQUASHFS_XATTR=y
CONFIG_SQUASHFS_XZ=y
# IPSec
CONFIG_NET_IPVTI=y
CONFIG_INET_AH=y
CONFIG_INET_ESP=y
CONFIG_INET_IPCOMP=y
CONFIG_INET_XFRM_MODE_TRANSPORT=y
CONFIG_INET_XFRM_MODE_TUNNEL=y
CONFIG_INET_XFRM_MODE_BEET=y
CONFIG_INET6_AH=y
CONFIG_INET6_ESP=y
CONFIG_INET6_IPCOMP=y
CONFIG_INET6_XFRM_MODE_TRANSPORT=y
CONFIG_INET6_XFRM_MODE_TUNNEL=y
CONFIG_INET6_XFRM_MODE_BEET=y
# crypto support
CONFIG_CRYPTO_ALGAPI=y
CONFIG_CRYPTO_ALGAPI2=y
CONFIG_CRYPTO_AEAD=y
CONFIG_CRYPTO_AEAD2=y
CONFIG_CRYPTO_BLKCIPHER=y
CONFIG_CRYPTO_BLKCIPHER2=y
CONFIG_CRYPTO_HASH=y
CONFIG_CRYPTO_HASH2=y
CONFIG_CRYPTO_RNG2=y
CONFIG_CRYPTO_PCOMP2=y
CONFIG_CRYPTO_MANAGER=y
CONFIG_CRYPTO_MANAGER2=y
# CONFIG_CRYPTO_USER is not set
CONFIG_CRYPTO_CTS=y
CONFIG_CRYPTO_CTR=y
CONFIG_CRYPTO_CBC=y
CONFIG_CRYPTO_XTS=y
CONFIG_CRYPTO_CCM=y
CONFIG_CRYPTO_GCM=y
CONFIG_CRYPTO_HMAC=y
CONFIG_CRYPTO_RMD128=y
CONFIG_CRYPTO_RMD160=y
CONFIG_CRYPTO_RMD256=y
CONFIG_CRYPTO_RMD320=y
CONFIG_CRYPTO_SHA1_SSSE3=m
CONFIG_CRYPTO_SHA256=y
CONFIG_CRYPTO_SHA512=y
CONFIG_CRYPTO_AES=y
CONFIG_CRYPTO_AES_X86_64=y
CONFIG_CRYPTO_AES_NI_INTEL=n
CONFIG_CRYPTO_BLOWFISH_X86_64=y
CONFIG_CRYPTO_SALSA20_X86_64=y
CONFIG_CRYPTO_TWOFISH_X86_64_3WAY=y
CONFIG_CRYPTO_DEFLATE=y
CONFIG_CRYPTO_ZLIB=y
CONFIG_CRYPTO_LZO=y
# rtc
CONFIG_RTC=y
# devtmpfs, required by udev
CONFIG_DEVTMPFS=y
CONFIG_DEVTMPFS_MOUNT=y
# library routines
CONFIG_CRC16=y
CONFIG_CRC32=y
CONFIG_CRC32_SLICEBY8=y
CONFIG_ZLIB_INFLATE=y
CONFIG_LZO_COMPRESS=y
CONFIG_LZO_DECOMPRESS=y
CONFIG_LZ4_DECOMPRESS=y
CONFIG_XZ_DEC=y
CONFIG_XZ_DEC_X86=y
CONFIG_XZ_DEC_BCJ=y
CONFIG_DECOMPRESS_GZIP=y
CONFIG_DECOMPRESS_BZIP2=y
CONFIG_DECOMPRESS_LZMA=y
CONFIG_DECOMPRESS_XZ=y
CONFIG_DECOMPRESS_LZO=y
CONFIG_DECOMPRESS_LZ4=y
KERNEOF
# build and install kernel, using the config created above
genkernel --install --symlink --oldconfig --bootloader=grub all
EOF

# Install git
cat <<EOF >> "/mnt/gentoo/etc/portage/package.use/git"
dev-vcs/git -webdav
EOF

chroot "/mnt/gentoo" emerge dev-vcs/git

# Install vim
cat <<EOF >> "/mnt/gentoo/etc/portage/package.accept_keywords/vim"
app-vim/bash-support ~x86 ~amd64
EOF

chroot "/mnt/gentoo" emerge app-editors/vim
chroot "/mnt/gentoo" emerge app-vim/bash-support
chroot "/mnt/gentoo" emerge app-admin/sudo

# Install syslog
chroot "/mnt/gentoo" /bin/bash <<EOF
emerge app-admin/rsyslog
rc-update add rsyslog default
EOF

# use grub2
cat <<EOF >> "/mnt/gentoo/etc/portage/package.accept_keywords/grub"
sys-boot/grub:2
EOF

# install grub
chroot "/mnt/gentoo" emerge grub

# tweak timeout
chroot "/mnt/gentoo" sed -i "s/.*GRUB_TIMEOUT=.*/GRUB_TIMEOUT=1/g" /etc/default/grub

# Setup a bootable grub config.
chroot "/mnt/gentoo" /bin/bash <<EOF
source /etc/profile && \
env-update && \
grep -v rootfs /proc/mounts > /etc/mtab && \
mkdir -p /boot/grub2 && \
ln -sf /boot/grub2 /boot/grub && \
grub-install --no-floppy /dev/sda && \
grub-mkconfig -o /boot/grub/grub.cfg
EOF

chroot /mnt/gentoo /bin/bash <<EOF
echo "magma.builder" > /etc/hostname
EOF

# Configure the system password which will be used after the reboot.
chroot /mnt/gentoo /bin/bash <<EOF
passwd<<PEOF
vagrant
vagrant
PEOF
EOF

# Configure the vagrant user account.
chroot /mnt/gentoo /bin/bash <<EOF
useradd vagrant
passwd vagrant<<PEOF
vagrant
vagrant
PEOF

mkdir -p ~vagrant/.ssh
echo 'ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEA6NF8iallvQVp22WDkTkyrtvp9eWW6A8YVr+kz4TjGYe7gHzIw+niNltGEFHzD8+v1I2YJ6oXevct1YeS0o9HZyN1Q9qgCgzUFtdOKLv6IedplqoPkcmF0aYet2PkEDo3MlTBckFXPITAMzF8dJSIFo9D8HfdOV0IAdx4O7PtixWKn5y2hMNG0zQPyUecp4pzC6kivAIhyfHilFR61RGL+GPXQ2MWZWFYbAGjyiYJnAmCP3NOTd0jMZEnDkbUvxhMmBYSdETk1rRgm+R4LOzFUGaHqHDLKLX+FIPKcF96hrucXzcWyLbIbEgE98OHlnVYCzRdK8jlqm8tehUc9c9WhQ== vagrant insecure public key' > ~vagrant/.ssh/authorized_keys

chmod 600 ~vagrant/.ssh/authorized_keys
chmod 700 ~vagrant/.ssh

chown vagrant:vagrant ~vagrant/.ssh/authorized_keys
chown vagrant:vagrant ~vagrant/.ssh
EOF

# Reboot onto the freshly installed system.
reboot

install
url --url=https://mirrors.kernel.org/centos/6/os/x86_64/
repo --name=debug --baseurl=http://debuginfo.centos.org/6/x86_64/
repo --name=extras --baseurl=https://mirrors.kernel.org/centos/6/extras/x86_64/
repo --name=updates --baseurl=https://mirrors.kernel.org/centos/6/updates/x86_64/
repo --name=epel --baseurl=https://mirrors.kernel.org/fedora-epel/6/x86_64/
repo --name=epel-debuginfo --baseurl=https://mirrors.kernel.org/fedora-epel/6/SRPMS/
lang en_US.UTF-8
keyboard us
timezone US/Pacific
text
firstboot --disabled
selinux --enforcing
firewall --enabled --service=ssh --port=6000:tcp,6050:tcp,7000:tcp,7050:tcp,7500:tcp,7501:tcp,7550:tcp,7551:tcp,8000:tcp,8050:tcp,8500:tcp,8550:tcp,9000:tcp,9050:tcp,9500:tcp,9550:tcp,10000:tcp,10050:tcp,10500:tcp,10550:tcp
network --device eth0 --bootproto dhcp --noipv6 --hostname=magma.local
zerombr
clearpart --all --initlabel
bootloader --location=mbr --append="no_timer_check console=tty0 console=ttyS0,115200n8 net.ifnames=0 biosdevname=0 elevator=noop"
autopart
rootpw magma
authconfig --enableshadow --passalgo=sha512
reboot --eject
xconfig --startxonboot

%packages --nobase
@debugging
@development
@console-internet
@security-tools
@desktop-debugging
@general-desktop
@internet-applications
@x11
abrt
abrt-addon-ccpp
abrt-addon-kerneloops
abrt-addon-python
abrt-cli
abrt-desktop
abrt-gui
abrt-libs
abrt-tui
archivemount
at
attr
audit
audit-libs
audit-libs-devel
audit-libs-python
audit-viewer
autoconf
autofs
automake
bash
bind-libs
bind-utils
binutils
binutils-devel
bzip2
bzip2-devel
bzip2-libs
checkpolicy
chkconfig
cmake
control-center
control-center-extra
control-center-filesystem
coreutils
coreutils-libs
cpio
cpp
cpuspeed
crontabs
crypto-utils
cryptsetup-luks
cryptsetup-luks-libs
cscope
ctags
curl
diffstat
diffuse
diffutils
doxygen
eclipse-birt
eclipse-callgraph
eclipse-cdt
eclipse-changelog
eclipse-dtp
eclipse-emf
eclipse-gef
eclipse-jdt
eclipse-linuxprofilingframework
eclipse-mylyn
eclipse-mylyn-cdt
eclipse-mylyn-java
eclipse-mylyn-pde
eclipse-mylyn-trac
eclipse-mylyn-webtasks
eclipse-mylyn-wikitext
eclipse-oprofile
eclipse-pde
eclipse-platform
eclipse-rcp
eclipse-rpm-editor
eclipse-rse
eclipse-subclipse
eclipse-subclipse-graph
eclipse-svnkit
eclipse-swt
eclipse-valgrind
ed
ElectricFence
elfutils
elfutils-devel
elfutils-libelf
elfutils-libelf-devel
elfutils-libs
ethtool
evolution
evolution-data-server
evolution-data-server-devel
evolution-help
evolution-mapi
expect
file
file-devel
file-libs
file-roller
filesystem
findutils
finger
flex
ftp
fuse
fuse-libs
gawk
gcc
gcc-c++
gcc-gfortran
gcc-gnat
gcc-java
gcc-objc
gcc-objc++
gd
gdb
gdb-gdbserver
gdbm
gdbm-devel
gdm
gdm-libs
gdm-plugin-fingerprint
gdm-user-switch-applet
geany
gedit
gedit-plugins
genisoimage
gettext
gettext-devel
gettext-libs
giflib
git
glib2
glib2-devel
glibc
glibc-common
glibc-devel
glibc-headers
glibc-utils
glib-networking
gnupg2
gnutls
gnutls-devel
gnutls-utils
gperf
gpgme
gpm-libs
grep
groff
grub
gzip
hdparm
httpd
httpd-devel
httpd-manual
httpd-tools
hwdata
imake
indent
info
iotop
iproute
iptables
iptables-devel
iptables-ipv6
iptraf
iputils
jetty-eclipse
jwhois
less
libaio
libarchive
libattr
libattr-devel
libbsd
libbsd-devel
libcurl
libcurl-devel
libevent
libevent-devel
libevent-doc
libevent-headers
libjpeg-turbo
libjpeg-turbo-devel
libmemcached
libnotify
libnotify-devel
libpng
libpng-devel
librsvg2
librsvg2-devel
libstdc++
libstdc++-devel
libstdc++-docs
libuuid
libuuid-devel
libxslt
libxslt-devel
libzip
lm_sensors
lm_sensors-devel
lm_sensors-libs
lockdev
logrotate
lslk
lsof
ltrace
lua
lucene
lucene-contrib
lvm2
lvm2-libs
lzo
m2crypto
m4
make
man
man-pages
man-pages-overrides
mc
mcelog
memtest86+
mercurial
meld
mlocate
mod_dnssd
mod_perl
mod_ssl
mousetweaks
mysql
mysql-bench
mysql-connector-java
mysql-connector-odbc
mysql-devel
mysql-libs
MySQL-python
mysql-server
nano
nasm
nautilus
nautilus-extensions
nautilus-open-terminal
nautilus-sendto
nc
ncurses
ncurses-base
ncurses-devel
ncurses-libs
net-snmp
net-snmp-devel
net-snmp-libs
net-snmp-perl
net-snmp-python
net-snmp-utils
net-tools
NetworkManager
NetworkManager-glib
NetworkManager-gnome
nmap
ntp
ntpdate
numpy
openssh
openssh-askpass
openssh-clients
openssh-server
openssl
openssl-devel
oprofile
oprofile-gui
oprofile-jit
parted
patch
patchutils
pcre
perf
pkgconfig
pm-utils
postfix
powertop
psutils
rdate
readahead
readline
readline-devel
regexp
rpm-build
rpmdevtools
rsync
screen
sed
selinux-policy
selinux-policy-targeted
setools-console
setools-libs
setools-libs-python
setroubleshoot
setroubleshoot-plugins
setroubleshoot-server
shared-mime-info
sqlite
sqlite-devel
strace
stunnel
sysstat
tcpdump
tcp_wrappers
tcsh
telnet
tokyocabinet
tokyocabinet-devel
unzip
valgrind
valgrind-devel
vim-common
vim-enhanced
vim-minimal
wget
which
wireshark
wireshark-gnome
words
xmlrpc3-client
xmlrpc3-common
xmlrpc-c
xmlrpc-c-client
xmlto
xz
xz-devel
xz-libs
xz-lzma-compat
yum-utils
zip
zlib
zlib-devel
-microcode_ctl
-*firmware
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
    yum --assumeyes install eject hyperv-daemons
    chkconfig hypervvssd on
    chkconfig hypervkvpd on
#    eject /dev/cdrom
fi

%end

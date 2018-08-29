#!/bin/bash

error() {
        if [ $? -ne 0 ]; then
                printf "\n\nbase configuration script failure...\n\n";
                exit 1
        fi
}

# Disable the broken repositories.
truncate --size=0 /etc/yum.repos.d/CentOS-Media.repo /etc/yum.repos.d/CentOS-Vault.repo

# Tell yum to retry 128 times before failing, so unattended installs don't skip packages when errors occur.
printf "\nretries=128\ndeltarpm=0\nmetadata_expire=0\nmirrorlist_expire=0\n" >> /etc/yum.conf

# Disable IPv6 or yum will resolve mirror names to IPv6 address and then fail to connect with them.
sysctl net.ipv6.conf.all.disable_ipv6=1

# Ensure a nameserver is being used that won't return an IP for non-existent domain names.
printf "nameserver 4.2.2.1\nnameserver 4.2.2.2\nnameserver 208.67.220.220\nnameserver 208.67.222.222\n"> /etc/resolv.conf

# Set the local hostname to resolve properly.
printf "\n127.0.0.1	magma.builder\n\n" >> /etc/hosts

# Import the update key.
rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-6

# Update the base install first.
yum --assumeyes update; error

# The entropy daemon is optional, but improves the availability of entropy.
yum --assumeyes --enablerepo=extras install epel-release; error

# Import the EPEL key.
rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-6

# Install the basic packages we'd expect to find.
yum --assumeyes install deltarpm net-tools sudo dmidecode yum-utils man bash-completion man-pages vim-common vim-enhanced sysstat bind-utils jwhois wget dos2unix unix2dos lsof telnet net-tools coreutils grep gawk sed curl patch sysstat make cmake libarchive texinfo autoconf automake libtool gcc-c++ libstdc++-devel gcc cpp ncurses-devel glibc-devel glibc-headers kernel-headers; error

deltarpm net-tools sudo dmidecode yum-utils bash-completion man man-pages vim-enhanced sysstat bind-utils jwhois wget dos2unix unix2dos lsof telnet net-tools coreutils grep gawk sed curl patch sysstat make cmake libarchive texinfo autoconf automake libtool gcc-c++ libstdc++-devel gcc cpp ncurses-devel glibc-devel glibc-headers kernel-headers
deltarpm net-tools sudo dmidecode yum-utils bash-completion man man-pages vim-enhanced sysstat bind-utils jwhois wget dos2unix unix2dos lsof telnet net-tools coreutils grep gawk sed curl patch sysstat make cmake libarchive texinfo autoconf automake libtool gcc-c++ libstdc++-devel gcc cpp ncurses-devel glibc-devel glibc-headers kernel-headers

# Run update a second time, just in case it failed the first time. Mirror timeoutes and cosmic rays
# often interupt the the provisioning process.
yum --assumeyes --disablerepo=epel update; error

# Configure pip in case anybody needs it. We do this seperately to make it easier to skip/remove.
yum --assumeyes install python-pip; error

# Remove the spurious pip warning about an insecure urllib3 library.
patch /usr/lib/python2.6/site-packages/pip/_vendor/requests/packages/urllib3/util/ssl_.py <<-EOF
diff --git a/ssl_.py b/ssl_.py
index b846d42..b22f7a3 100644
--- a/ssl_.py
+++ b/ssl_.py
@@ -81,14 +81,6 @@ except ImportError:
             self.ciphers = cipher_suite

         def wrap_socket(self, socket, server_hostname=None):
-            warnings.warn(
-                'A true SSLContext object is not available. This prevents '
-                'urllib3 from configuring SSL appropriately and may cause '
-                'certain SSL connections to fail. For more information, see '
-                'https://urllib3.readthedocs.org/en/latest/security.html'
-                '#insecureplatformwarning.',
-                InsecurePlatformWarning
-            )
             kwargs = {
                 'keyfile': self.keyfile,
                 'certfile': self.certfile,
EOF

# Disable IPv6 by default.
printf "\n\nnet.ipv6.conf.all.disable_ipv6 = 1\n" >> /etc/sysctl.conf

sed -i -e "s/IPV6INIT=yes/IPV6INIT=no/g" /etc/sysconfig/network-scripts/ifcfg-eth0
sed -i -e "s/IPV6_AUTOCONF=yes/IPV6_AUTOCONF=no/g" /etc/sysconfig/network-scripts/ifcfg-eth0
sed -i -e "s/IPV6_DEFROUTE=yes/IPV6_DEFROUTE=no/g" /etc/sysconfig/network-scripts/ifcfg-eth0
sed -i -e "s/IPV6_PEERDNS=yes/IPV6_PEERDNS=no/g" /etc/sysconfig/network-scripts/ifcfg-eth0
sed -i -e "s/IPV6_PEERROUTES=yes/IPV6_PEERROUTES=no/g" /etc/sysconfig/network-scripts/ifcfg-eth0

# Delete the network manager line and recreate it.
sed -i -e "/NM_CONTROLLED/d" /etc/sysconfig/network-scripts/ifcfg-eth0

# Ensure good DNS servers are being used.
printf "DNS1=\"4.2.2.1\"\n" >> /etc/sysconfig/network-scripts/ifcfg-eth0
printf "DNS2=\"4.2.2.2\"\n" >> /etc/sysconfig/network-scripts/ifcfg-eth0
printf "DNS3=\"208.67.220.220\"\n" >> /etc/sysconfig/network-scripts/ifcfg-eth0

# Add extra options so missing or unplugged ethernet devices don't cause problems during boot.
printf "IPV4_FAILURE_FATAL=\"no\"\n" >> /etc/sysconfig/network-scripts/ifcfg-eth0
printf "PERSISTENT_DHCLIENT=\"yes\"\n" >> /etc/sysconfig/network-scripts/ifcfg-eth0
printf "NM_CONTROLLED=\"no\"\n" >> /etc/sysconfig/network-scripts/ifcfg-eth0
printf "DHCPRELEASE=\"yes\"\n" >> /etc/sysconfig/network-scripts/ifcfg-eth0
printf "LINKDELAY=\"5\"\n" >> /etc/sysconfig/network-scripts/ifcfg-eth0

# Don't wait for the interface to be configured during boot.
printf "NETWORKDELAY=\"\"\n" >> /etc/sysconfig/network

# Make sure the dhcp client continues to retry.
printf "timeout 10;\n" >> /etc/dhcp/dhclient-eth0.conf
printf "retry 5;\n" >> /etc/dhcp/dhclient-eth0.conf

# Close a potential security hole.
chkconfig netfs off

# Prevent udev from persisting the network interface rules.
rm -f /etc/udev/rules.d/70-persistent-net.rules
sed -i -e 's/\(\[ "\$comment" \] && echo "# \$comment"\)/# \1/g' /lib/udev/write_net_rules
sed -i -e 's/\(echo "SUBSYSTEM==\\\"net\\\", ACTION==\\\"add\\\"\$match, NAME\=\\\"\$name\\\""\)/# \1/g' /lib/udev/write_net_rules

# Increase the history size.
printf "export HISTSIZE=\"100000\"\n" > /etc/profile.d/histsize.sh
chcon "system_u:object_r:bin_t:s0" /etc/profile.d/histsize.sh
chmod 644 /etc/profile.d/histsize.sh

# Always use vim, even as root.
printf "alias vi vim\n" > /etc/profile.d/vim.csh
printf "# For bash/zsh, if no alias is already set.\nalias vi >/dev/null 2>&1 || alias vi=vim\n" > /etc/profile.d/vim.sh

# Set the timezone to Pacific time.
printf "ZONE=\"America/Los_Angeles\"\n" > /etc/sysconfig/clock

# If postfix is installed, configure it use only ipv4 interfaces, or it will fail to start properly.
if [ -f /etc/postfix/main.cf ]; then
  sed -i "s/^inet_protocols.*$/inet_protocols = ipv4/g" /etc/postfix/main.cf
fi

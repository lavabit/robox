#!/bin/bash

retry() {
  local COUNT=1
  local RESULT=0
  while [[ "${COUNT}" -le 10 ]]; do
    [[ "${RESULT}" -ne 0 ]] && {
      [ "`which tput 2> /dev/null`" != "" ] && tput setaf 1
      echo -e "\n${*} failed... retrying ${COUNT} of 10.\n" >&2
      [ "`which tput 2> /dev/null`" != "" ] && tput sgr0
    }
    "${@}" && { RESULT=0 && break; } || RESULT="${?}"
    COUNT="$((COUNT + 1))"

    # Increase the delay with each iteration.
    DELAY="$((DELAY + 10))"
    sleep $DELAY
  done

  [[ "${COUNT}" -gt 10 ]] && {
    [ "`which tput 2> /dev/null`" != "" ] && tput setaf 1
    echo -e "\nThe command failed 10 times.\n" >&2
    [ "`which tput 2> /dev/null`" != "" ] && tput sgr0
  }

  return "${RESULT}"
}

error() {
        if [ $? -ne 0 ]; then
                printf "\n\nbase configuration script failure...\n\n";
                exit 1
        fi
}

# Tell yum to retry 128 times before failing, so unattended installs don't skip packages when errors occur.
printf "\nretries=128\nmetadata_expire=0\nmirrorlist_expire=0\n" >> /etc/yum.conf

# Disable the broken repositories.
truncate --size=0 /etc/yum.repos.d/CentOS-Media.repo /etc/yum.repos.d/CentOS-Vault.repo

# Import the update key.
rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-6; error

# Update the base install first.
retry yum --assumeyes update; error

# Install the basic packages we'd expect to find.
retry yum --assumeyes install deltarpm net-tools sudo dmidecode yum-utils man bash-completion man-pages vim-common vim-enhanced sysstat bind-utils jwhois wget dos2unix unix2dos lsof telnet net-tools coreutils grep gawk sed curl patch sysstat make cmake libarchive texinfo autoconf automake libtool gcc-c++ libstdc++-devel gcc cpp ncurses-devel glibc-devel glibc-headers kernel-headers psmisc; error

# Run update a second time, just in case it failed the first time. Mirror timeoutes and cosmic rays
# often interupt the the provisioning process.
retry yum --assumeyes --disablerepo=epel update; error

if [ -f /etc/yum.repos.d/CentOS-Vault.repo.rpmnew ]; then
  rm --force /etc/yum.repos.d/CentOS-Vault.repo.rpmnew
fi

# Configure pip in case anybody needs it. We do this seperately to make it easier to skip/remove.
retry yum --assumeyes install python-pip; error

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

# Close a potential security hole.
chkconfig netfs off; error

# Increase the history size.
printf "export HISTSIZE=\"100000\"\n" > /etc/profile.d/histsize.sh
chcon "system_u:object_r:bin_t:s0" /etc/profile.d/histsize.sh
chmod 644 /etc/profile.d/histsize.sh

# Always use vim, even as root.
printf "alias vi vim\n" > /etc/profile.d/vim.csh
printf "# For bash/zsh, if no alias is already set.\nalias vi >/dev/null 2>&1 || alias vi=vim\n" > /etc/profile.d/vim.sh

# Set the timezone to Pacific time.
printf "ZONE=\"America/Los_Angeles\"\n" > /etc/sysconfig/clock

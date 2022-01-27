#!/bin/bash -x

retry() {
  local COUNT=1
  local RESULT=0
  while [[ "${COUNT}" -le 10 ]]; do
    [[ "${RESULT}" -ne 0 ]] && {
      [ "`which tput 2> /dev/null`" != "" ] && [ ! -z "$TERM" ] && tput setaf 1
      echo -e "\\n${*} failed... retrying ${COUNT} of 10.\\n" >&2
      [ "`which tput 2> /dev/null`" != "" ] && [ ! -z "$TERM" ] && tput sgr0
    }
    "${@}" && { RESULT=0 && break; } || RESULT="${?}"
    COUNT="$((COUNT + 1))"

    # Increase the delay with each iteration.
    DELAY="$((DELAY + 10))"
    sleep $DELAY
  done

  [[ "${COUNT}" -gt 10 ]] && {
    [ "`which tput 2> /dev/null`" != "" ] && [ ! -z "$TERM" ] && tput setaf 1
    echo -e "\\nThe command failed 10 times.\\n" >&2
    [ "`which tput 2> /dev/null`" != "" ] && [ ! -z "$TERM" ] && tput sgr0
  }

  return "${RESULT}"
}

error() {
  if [ $? -ne 0 ]; then
    printf "\n\nThe VirtualBox install failed...\n\n"

    if [ -f /var/log/VBoxGuestAdditions.log ]; then
      printf "\n\n/var/log/VBoxGuestAdditions.log\n\n"
      cat /var/log/VBoxGuestAdditions.log
    else
      printf "\n\nThe /var/log/VBoxGuestAdditions.log is missing...\n\n"
    fi

    if [ -f /var/log/vboxadd-install.log ]; then
      printf "\n\n/var/log/vboxadd-install.log\n\n"
      cat /var/log/vboxadd-install.log
    else
      printf "\n\nThe /var/log/vboxadd-install.log is missing...\n\n"
    fi

    if [ -f /var/log/vboxadd-setup.log ]; then
      printf "\n\n/var/log/vboxadd-setup.log\n\n"
      cat /var/log/vboxadd-setup.log
    else
      printf "\n\nThe /var/log/vboxadd-setup.log is missing...\n\n"
    fi

    exit 1
  fi
}

# Ensure dmidecode is available.
retry apk add dmidecode

# Bail if we are not running atop VirtualBox.
if [[ `dmidecode -s system-product-name` != "VirtualBox" ]]; then
    exit 0
fi

# Install the Virtual Box Tools from source
printf "Installing the Virtual Box Tools.\n"

# Install build dependencies
retry apk add gcc g++ yasm nasm make shadow linux-virtgrsec-dev linux-headers zlib zlib-dev bzip2 bzip2-dev

# Read in the version number.
VBOXVERSION=`cat /root/VBoxVersion.txt`

# The group vboxsf is needed for shared folder access.
getent group vboxsf >/dev/null || (echo vagrant | groupadd --system vboxsf); error
getent passwd vboxadd >/dev/null || (echo vagrant | useradd --system --gid bin --home-dir /var/run/vboxadd --shell /sbin/nologin vboxadd); error

# We cheat and remove the real useradd/groupadd and replace them with dummies
# so the installer thinks its otherwise invalid attempts actually worked..
apk del shadow
printf "#!/bin/bash\nreturn 0\n" > /sbin/useradd
printf "#!/bin/bash\nreturn 0\n" > /sbin/groupadd
chmod +x /sbin/useradd
chmod +x /sbin/groupadd

# Mount the ISO.
mkdir -p /mnt/virtualbox; error
modprobe loop; error
LOOP=`losetup -f`
losetup $LOOP /root/VBoxGuestAdditions.iso
mount -t iso9660 -o ro $LOOP /mnt/virtualbox; error

# Replace ldconfig with output the script will understand.
mv /sbin/ldconfig /root/ldconfig.bak
cat <<-EOF > /sbin/ldconfig
printf "/lib:\n"
echo "/root/ldconfig.bak" > /sbin/ldconfig
EOF
chmod +x /sbin/ldconfig

# The setup script likes to write a module config here.
mkdir -p /etc/depmod.d; error

# We can't trust the status code that gets returned, so we trigger a failure
# if the service fails to start below.
sh /mnt/virtualbox/VBoxLinuxAdditions.run --nox11

# Test if the vboxsf module is present
[ -s "/lib/modules/$(uname -r)/misc/vboxsf.ko" ]; error

# Restore the real ldconfig binary.
mv /root/ldconfig.bak /sbin/ldconfig; error

# Configure the service.
rc-update add vboxadd default && rc-service vboxadd start; error

# Cleanup.
umount /mnt/virtualbox; error

rm -f /sbin/useradd
rm -f /sbin/groupadd
rm -rf /mnt/virtualbox
rm -rf /root/VBoxVersion.txt
rm -rf /root/VBoxGuestAdditions.iso

printf "Finished installing the Virtual Box Tools.\n"

# Boosts the available entropy which allows magma to start faster.
retry apk add haveged

# Autostart the haveged daemon.
rc-update add haveged default && rc-service haveged start

#!/bin/sh -eux
###!/bin/bash -eux
# make shure it will run in any case


retry() {
  local COUNT=1
  local RESULT=0
  while [[ "${COUNT}" -le 10 ]]; do
    [[ "${RESULT}" -ne 0 ]] && {
      [ "`which tput 2> /dev/null`" != "" ] && tput setaf 1
      echo -e "\\n${*} failed... retrying ${COUNT} of 10.\\n" >&2
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
    echo -e "\\nThe command failed 10 times.\\n" >&2
    [ "`which tput 2> /dev/null`" != "" ] && tput sgr0
  }

  return "${RESULT}"
}

if ! grep -q '^[^#].\+alpine/.\+/community' /etc/apk/repositories; then
    # Add community repository entry based on the "main" repo URL
    __REPO=$(grep '^[^#].\+alpine/.\+/main\>' /etc/apk/repositories)
    echo "${__REPO}" | sed -e 's/main/community/' >> /etc/apk/repositories
fi


# Ensure dmidecode is available.
retry apk add dmidecode

# Bail if we are not running atop VirtualBox.
if [[ `dmidecode -s system-product-name` != "VirtualBox" ]]; then
    exit 0
fi

if [[ "$PACKER_BUILD_NAME" =~ ^(generic|magma)-(alpine3[5-7])-(vmware|hyperv|libvirt|parallels|virtualbox)$ ]]; then

	# Install the Virtual Box Tools from the Linux Guest Additions ISO.
	printf "Installing the Virtual Box Tools.\n"

	# Add the testing repository (which isn't available over HTTPS).
	printf "@testing http://nl.alpinelinux.org/alpine/edge/testing\n" >> /etc/apk/repositories

	# Add the edge repository entry based on the "main" repo URL.
	printf "@edge http://nl.alpinelinux.org/alpine/edge/main/\n" >> /etc/apk/repositories

	# Update the APK cache.
	retry apk update --no-cache

	# Install the VirtualBox kernel modules for guest services.
	retry apk add linux-hardened@edge virtualbox-additions-hardened@testing

	# Autoload the virtualbox kernel modules.
	echo vboxpci >> /etc/modules
	echo vboxdrv >> /etc/modules
	echo vboxnetflt >> /etc/modules

	rm -rf /root/VBoxVersion.txt
	rm -rf /root/VBoxGuestAdditions.iso

else

	apk info --installed linux-vanilla && apkRESULT="${?}" || apkRESULT="${?}"
	if [[ $apkRESULT == "0" ]]; then
		retry apk add virtualbox-guest-additions virtualbox-guest-modules-vanilla
	# Autoload the virtualbox kernel modules.
	echo vboxguest >> /etc/modules
	echo vboxsf >> /etc/modules
	echo vboxvideo >> /etc/modules
	fi

	apk info --installed linux-virt && apkRESULT="${?}" || apkRESULT="${?}"
	if [[ $apkRESULT == "0" ]]; then
		retry apk add virtualbox-guest-additions virtualbox-guest-modules-virt
	# Autoload the virtualbox kernel modules.
	echo vboxguest >> /etc/modules
	echo vboxsf >> /etc/modules
	##echo vboxvideo >> /etc/modules
	fi

	rm -rf /root/VBoxVersion.txt
	rm -rf /root/VBoxGuestAdditions.iso

fi


# Read in the version number.
# export VBOXVERSION=`cat /root/VBoxVersion.txt`
#
# export DEBIAN_FRONTEND=noninteractive
# apt-get --assume-yes install dkms build-essential module-assistant linux-headers-$(uname -r)
#
# mkdir -p /mnt/virtualbox
# mount -o loop /root/VBoxGuestAdditions.iso /mnt/virtualbox
#
# /mnt/virtualbox/VBoxLinuxAdditions.run --nox11
# ln -s /opt/VBoxGuestAdditions-$VBOXVERSION/lib/VBoxGuestAdditions /usr/lib/VBoxGuestAdditions
#
# umount /mnt/virtualbox
rm -rf /root/VBoxVersion.txt
rm -rf /root/VBoxGuestAdditions.iso

# Boosts the available entropy which allows magma to start faster.
retry apk add haveged

# Autostart the haveged daemon.
rc-update add haveged default && rc-service haveged start

#!/bin/bash -eux

# Now that the system is running atop the updated kernel, we can install the
# development files for the kernel. These files are required to compile the
# virtualization kernel modules later in the provisioning process.
dnf --assumeyes install kernel-tools kernel-devel kernel-headers

printf "\n\n\n\n" 1>&2
rpm -qa | grep kernel | sort
printf "\n\n\n\n" 1>&2
dnf --enablerepo=* repolist
printf "\n\n\n\n" 1>&2

# # Remove the duplicate UEK firmware packatges first.
# PACKAGES=`rpm --query --last kernel-uek-firmware | awk -F' ' '{print $1}' | tail --lines=+2`
# if [ ! -z $PACKAGES ]; then
#   rpm --erase $PACKAGES
# fi
#
# # Then remove the duplicate UEK kernel packages.
# PACKAGES=`rpm --query --last kernel-uek | awk -F' ' '{print $1}' | tail --lines=+2`
# if [ ! -z $PACKAGES ]; then
#   rpm --erase $PACKAGES
# fi
#
# # Make sure we have the right kernel-uek-devel package installed, or the VirtualBox
# # addons won't build properly.
# dnf --enablerepo=ol8_UEKR* --assumeyes install kernel-uek-devel-`uname -r`

# Now that the system is running on the updated kernel, we can remove the
# old kernel(s) from the system.
if [[ `rpm -q kernel | wc -l` != 1 ]]; then
  package-cleanup --assumeyes --oldkernels --count=1
fi

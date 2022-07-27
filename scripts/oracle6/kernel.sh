#!/bin/bash -eux

# Now that the system is running atop the updated kernel, we can install the
# development files for the kernel. These files are required to compile the
# virtualization kernel modules later in the provisioning process.
yum --assumeyes install kernel-tools kernel-devel kernel-headers

# Remove the duplicate UEK firmware packages first.
PACKAGES=`rpm --query --last kernel-firmware | awk -F' ' '{print $1}' | tail --lines=+2`
if [ ! -z $PACKAGES ]; then
  rpm --erase $PACKAGES
fi

# Then remove the duplicate UEK kernel packages.
PACKAGES=`rpm --query --last kernel | awk -F' ' '{print $1}' | tail --lines=+2`
if [ ! -z $PACKAGES ]; then
  rpm --erase $PACKAGES
fi

# Make sure we have the right kernel-uek-devel package installed, or the VirtualBox
# addons won't build properly.
yum --assumeyes remove kernel-uek-*

# Now that the system is running on the updated kernel, we can remove the
# old kernel(s) from the system.
if [[ `rpm -q kernel | wc -l` != 1 ]]; then
  package-cleanup --assumeyes --oldkernels --count=1
fi

#!/bin/bash -eux

# Now that the system is running on the updated kernel, we can remove the
# old kernel(s) from the system.
if [[ `rpm -q kernel | wc -l` != 1 ]]; then
  package-cleanup --quiet --assumeyes --oldkernels --count=1
fi

# Now that the system is running atop the updated kernel, we can install the
# development files for the kernel. These files are required to compile the
# virtualization kernel modules later in the provisioning process.
yum --quiet --assumeyes install kernel-tools kernel-devel kernel-headers kernel-uek-devel

# Dump a list of installed kernel packages for the log file.
printf "\n------------------------------------------------------\n" && \
rpm --query --all | grep kernel | sort && \
printf -- "------------------------------------------------------\n"

# Remove the duplicate UEK firmware packatges first.
PACKAGES=`rpm --query --last kernel-uek-firmware | awk -F' ' '{print $1}' | tail --lines=+2`
if [ ! -z $PACKAGES ]; then
  rpm --erase $PACKAGES
fi

# Then remove the duplicate UEK kernel packages.
PACKAGES=`rpm --query --last kernel-uek | awk -F' ' '{print $1}' | tail --lines=+2`
if [ ! -z $PACKAGES ]; then
  rpm --erase $PACKAGES
fi

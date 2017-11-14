#!/bin/bash

error() {
        if [ $? -ne 0 ]; then
                printf "\n\ndnf failed...\n\n"
                exit 1
        fi
}


# Now that the system is running on the updated kernel, we can remove the
# old kernel(s) from the system.
#if [[ `rpm -q kernel | wc -l` != 1 ]]; then
#  package-cleanup --quiet --assumeyes --oldkernels --count=1; error
#fi

# Now that the system is running atop the updated kernel, we can install the
# development files for the kernel. These files are required to compile the
# virtualization kernel modules later in the provisioning process.
dnf --assumeyes install kernel-tools kernel-devel kernel-headers; error

#!/bin/bash -eux

# Now that the system is running on the updated kernel, we can remove the
# old kernel(s) from the system.
dnf remove $( dnf repoquery --installonly --latest-limit -1 -q kernel )

# Now that the system is running atop the updated kernel, we can install the
# development files for the kernel. These files are required to compile the
# virtualization kernel modules later in the provisioning process.
dnf --assumeyes install kernel-tools kernel-devel kernel-headers

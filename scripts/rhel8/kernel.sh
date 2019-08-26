#!/bin/bash -eux

# Check whether the install media is mounted, and if necessary mount it.
if [ ! -d /media/BaseOS/ ] || [ ! -d /media/AppStream/ ]; then
  mount /dev/cdrom /media || (printf "\nFailed mount RHEL cdrom.\n"; exit 1)
fi

# This probably doesn't apply, because network updates aren't being used, but
# were including it just in case that changes in the future. If a newer
# kernel were installed during the system update process, this would remove
# any duplicates/old kernel(s) from the system.
dnf remove $( dnf repoquery --installonly --latest-limit -1 -q kernel )

# Now that the system is running atop the updated kernel, we can install the
# development files for the kernel. These files are required to compile the
# virtualization kernel modules later in the provisioning process.
dnf --assumeyes install kernel-tools kernel-devel kernel-headers

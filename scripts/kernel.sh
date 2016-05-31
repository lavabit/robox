#!/bin/bash

# Now that the system is running on the updated kernel, we can remove the 
# old kernel(s) from the system.
package-cleanup --oldkernels --count=1

# Now that the system is running atop the updated kernel, we can install the 
# development files for the kernel. These files are required to compile the 
# virtualization kernel modules later in the provisioning process.
yum --assumeyes install kernel-devel


#!/bin/bash -eux

version=`grep VERSION= /etc/os-release | cut -f2 -d\" | cut -f1 -d\ `

# Remove locks to avoid dependency problems.
zypper --non-interactive removelock virtualbox-guest-tools || echo "The virtualbox-guest-tools lock removal failed."
zypper --non-interactive removelock virtualbox-guest-kmp-default || echo "The virtualbox-guest-kmp-defaul lock removal failed."

# Remove the default installation repository.
zypper --non-interactive removerepo "openSUSE-Leap-${version}-0"

# Add the default repositories for this release.
# zypper --non-interactive addrepo https://download.opensuse.org/distribution/leap/${version}/repo/oss/ openSUSE-Leap-${version}-Oss
# zypper --non-interactive addrepo https://download.opensuse.org/distribution/leap/${version}/repo/non-oss/ openSUSE-Leap-${version}-Non-Oss
# zypper --non-interactive addrepo https://download.opensuse.org/update/leap/${version}/oss/ openSUSE-Leap-${version}-Update
# zypper --non-interactive addrepo https://download.opensuse.org/update/leap/${version}/non-oss/ openSUSE-Leap-${version}-Update-Non-Oss

zypper --non-interactive addrepo https://mirrors.kernel.org/opensuse/distribution/leap/${version}/repo/oss/ openSUSE-Leap-${version}-Oss
zypper --non-interactive addrepo https://mirrors.kernel.org/opensuse/distribution/leap/${version}/repo/non-oss/ openSUSE-Leap-${version}-Non-Oss
zypper --non-interactive addrepo https://mirrors.kernel.org/opensuse/update/leap/${version}/oss/ openSUSE-Leap-${version}-Update
zypper --non-interactive addrepo https://mirrors.kernel.org/opensuse/update/leap/${version}/non-oss/ openSUSE-Leap-${version}-Update-Non-Oss


# Clean out any stale cache data.
zypper --non-interactive clean --all

# Refresh the repository metadata.
zypper --non-interactive refresh
# echo "Zypper repositories refreshed."

# Update the system packages.
zypper --non-interactive update --auto-agree-with-licenses
# echo "System updates have been applied."
# exit 0

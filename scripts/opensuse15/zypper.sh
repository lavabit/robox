#!/bin/bash -eux

version=`grep VERSION= /etc/os-release | cut -f2 -d\" | cut -f1 -d\ `

# Remove locks to avoid dependency problems.
zypper --non-interactive removelock virtualbox-guest-tools || echo "The virtualbox-guest-tools lock removal failed."
zypper --non-interactive removelock virtualbox-guest-kmp-default || echo "The virtualbox-guest-kmp-defaul lock removal failed."

# Remove the default installation repository.
zypper --non-interactive removerepo "`zypper repos 1 | head -1 | awk -F':' '{print $2}' | tr -d '[:space:]'`"

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

# Update the system packages.
zypper --non-interactive update --auto-agree-with-licenses

# Install the packages we'd expect to find.
zypper --non-interactive install --force-resolution man mlocate sysstat psmisc

# Update the locate database.
systemctl enable mlocate.timer && systemctl start mlocate.timer

# Force a reboot.
(sleep 30 ; /sbin/reboot) &

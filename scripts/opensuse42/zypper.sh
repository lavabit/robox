#!/bin/sh -eux

version=`grep VERSION= /etc/os-release | cut -f2 -d\" | cut -f1 -d\ `


# Remove locks to avoid dependency problems
zypper --non-interactive rl \*

zypper removerepo "openSUSE-${version}-0"

zypper ar https://mirrors.kernel.org/opensuse/distribution/leap/${version}/repo/oss/ openSUSE-Leap-${version}-Oss
zypper ar https://mirrors.kernel.org/opensuse/distribution/leap/${version}/repo/non-oss/ openSUSE-Leap-${version}-Non-Oss
zypper ar https://mirrors.kernel.org/opensuse/update/leap/${version}/oss/ openSUSE-Leap-${version}-Update
zypper ar https://mirrors.kernel.org/opensuse/update/leap/${version}/non-oss/ openSUSE-Leap-${version}-Update-Non-Oss

zypper refresh

#!/bin/bash -eux

retry() {
  local COUNT=1
  local RESULT=0
  while [[ "${COUNT}" -le 10 ]]; do
    [[ "${RESULT}" -ne 0 ]] && {
      [ "`which tput 2> /dev/null`" != "" ] && [ ! -z "$TERM" ] && tput setaf 1
      echo -e "\n${*} failed... retrying ${COUNT} of 10.\n" >&2
      [ "`which tput 2> /dev/null`" != "" ] && [ ! -z "$TERM" ] && tput sgr0
    }
    "${@}" && { RESULT=0 && break; } || RESULT="${?}"
    COUNT="$((COUNT + 1))"

    # Increase the delay with each iteration.
    DELAY="$((DELAY + 10))"
    sleep $DELAY
  done

  [[ "${COUNT}" -gt 10 ]] && {
    [ "`which tput 2> /dev/null`" != "" ] && [ ! -z "$TERM" ] && tput setaf 1
    echo -e "\nThe command failed 10 times.\n" >&2
    [ "`which tput 2> /dev/null`" != "" ] && [ ! -z "$TERM" ] && tput sgr0
  }

  return "${RESULT}"
}

# Tell yum to retry 128 times before failing, so unattended installs don't skip packages when errors occur.
printf "\nretries=128\ndeltarpm=0\nmetadata_expire=0\nmirrorlist_expire=0\n" >> /etc/yum.conf

# CentOS Repo Setup
sed -i -e "s/^#baseurl/baseurl/g" /etc/yum.repos.d/CentOS-Base.repo
sed -i -e "s/^mirrorlist/#mirrorlist/g" /etc/yum.repos.d/CentOS-Base.repo
sed -i -e "s/http:\/\/mirror.centos.org\/centos\//https:\/\/mirrors.edge.kernel.org\/centos\//g" /etc/yum.repos.d/CentOS-Base.repo
rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7

# Disable the physical media repos, along with fasttrack repos.
sed --in-place "s/^/# /g" /etc/yum.repos.d/CentOS-Media.repo
sed --in-place "s/# #/##/g" /etc/yum.repos.d/CentOS-Media.repo
sed --in-place "s/^/# /g" /etc/yum.repos.d/CentOS-Vault.repo
sed --in-place "s/# #/##/g" /etc/yum.repos.d/CentOS-Vault.repo
sed --in-place "s/^/# /g" /etc/yum.repos.d/CentOS-CR.repo
sed --in-place "s/# #/##/g" /etc/yum.repos.d/CentOS-CR.repo
sed --in-place "s/^/# /g" /etc/yum.repos.d/CentOS-fasttrack.repo
sed --in-place "s/# #/##/g" /etc/yum.repos.d/CentOS-fasttrack.repo

# EPEL Repo Setup
retry yum --quiet --assumeyes --enablerepo=extras install epel-release

sed -i -e "s/^#baseurl/baseurl/g" /etc/yum.repos.d/epel.repo
sed -i -e "s/^mirrorlist/#mirrorlist/g" /etc/yum.repos.d/epel.repo
# sed -i -e "s/http:\/\/download.fedoraproject.org\/pub\/epel\//https:\/\/mirrors.edge.kernel.org\/fedora-epel\//g" /etc/yum.repos.d/epel.repo
sed -i -e "s/http:\/\/download.fedoraproject.org\/pub\/epel\//https:\/\/mirrors.kernel.org\/fedora-epel\//g" /etc/yum.repos.d/epel.repo
rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-7

# Disable the testing repos.
sed --in-place "s/^/# /g" /etc/yum.repos.d/epel-testing.repo
sed --in-place "s/# #/##/g" /etc/yum.repos.d/epel-testing.repo

# Disable the subscription manager plugin.
if [ -f /etc/yum/pluginconf.d/subscription-manager.conf ]; then
  sed --in-place "s/^enabled=.*/enabled=0/g" /etc/yum/pluginconf.d/subscription-manager.conf
fi

# And disable the subscription maangber via the alternate dnf config file.
if [ -f /etc/dnf/plugins/subscription-manager.conf ]; then
  sed --in-place "s/^enabled=.*/enabled=0/g" /etc/dnf/plugins/subscription-manager.conf
fi

# Update the base install first.
retry yum --assumeyes update

# Install the basic packages we'd expect to find.
retry yum --assumeyes install deltarpm sudo dmidecode yum-utils bash-completion man man-pages mlocate vim-enhanced bind-utils jwhois wget dos2unix unix2dos lsof telnet net-tools coreutils grep gawk sed curl patch sysstat make cmake libarchive texinfo autoconf automake libtool gcc-c++ libstdc++-devel gcc cpp ncurses-devel glibc-devel glibc-headers kernel-headers psmisc

if [ -f /etc/yum.repos.d/CentOS-Vault.repo.rpmnew ]; then
  rm --force /etc/yum.repos.d/CentOS-Vault.repo.rpmnew
fi

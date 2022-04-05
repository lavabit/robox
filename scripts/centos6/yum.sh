#!/bin/bash

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

error() {
        if [ $? -ne 0 ]; then
                printf "\n\nbase configuration script failure...\n\n";
                exit 1
        fi
}

# Tell yum to retry 128 times before failing, so unattended installs don't skip packages when errors occur.
printf "\nretries=128\nmetadata_expire=0\nmirrorlist_expire=0\n" >> /etc/yum.conf

# CentOS Repo Setup
sed -i -e "s/^mirrorlist/#mirrorlist/g" /etc/yum.repos.d/CentOS-Base.repo
sed -i -e "s/^#[ ]\+baseurl=http:\/\/mirror.centos.org\/centos\//baseurl=https:\/\/vault.centos.org\/centos\//g" /etc/yum.repos.d/CentOS-Base.repo

# Disable the physical media repos, along with fasttrack repos.
sed --in-place "s/^/# /g" /etc/yum.repos.d/CentOS-Media.repo
sed --in-place "s/# #/##/g" /etc/yum.repos.d/CentOS-Media.repo
sed --in-place "s/^/# /g" /etc/yum.repos.d/CentOS-Vault.repo
sed --in-place "s/# #/##/g" /etc/yum.repos.d/CentOS-Vault.repo
sed --in-place "s/^/# /g" /etc/yum.repos.d/CentOS-fasttrack.repo
sed --in-place "s/# #/##/g" /etc/yum.repos.d/CentOS-fasttrack.repo

# Import the update key.
rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-6; error

# We'll want the EPEL repo installed.
retry yum --assumeyes --enablerepo=extras install deltarpm epel-release; error

# Import the EPEL key.
rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-6; error

# Update EPEL to use HTTPS and switch to archive server.
sed -i -e "s/^#[ ]\+baseurl/baseurl/g" /etc/yum.repos.d/epel.repo
sed -i -e "s/^mirrorlist/#mirrorlist/g" /etc/yum.repos.d/epel.repo
sed -i -e "s/http:\/\/download.fedoraproject.org\/pub\/epel\//https:\/\/archives.fedoraproject.org\/pub\/archive\/epel\//g" /etc/yum.repos.d/epel.repo



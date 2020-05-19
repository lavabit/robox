 #!/bin/bash -eux

retry() {
  local COUNT=1
  local RESULT=0
  while [[ "${COUNT}" -le 10 ]]; do
    [[ "${RESULT}" -ne 0 ]] && {
      [ "`which tput 2> /dev/null`" != "" ] && tput setaf 1
      echo -e "\n${*} failed... retrying ${COUNT} of 10.\n" >&2
      [ "`which tput 2> /dev/null`" != "" ] && tput sgr0
    }
    "${@}" && { RESULT=0 && break; } || RESULT="${?}"
    COUNT="$((COUNT + 1))"

    # Increase the delay with each iteration.
    DELAY="$((DELAY + 10))"
    sleep $DELAY
  done

  [[ "${COUNT}" -gt 10 ]] && {
    [ "`which tput 2> /dev/null`" != "" ] && tput setaf 1
    echo -e "\nThe command failed 10 times.\n" >&2
    [ "`which tput 2> /dev/null`" != "" ] && tput sgr0
  }

  return "${RESULT}"
}

# Tell dnf to retry 128 times before failing, so unattended installs don't skip packages when errors occur.
printf "\nretries=128\ndeltarpm=0\nmetadata_expire=0\nmirrorlist_expire=0\n" >> /etc/dnf.conf

# CentOS Repo Setup
sed -i -e "s/^#baseurl/baseurl/g" /etc/yum.repos.d/CentOS-Base.repo
sed -i -e "s/^mirrorlist/#mirrorlist/g" /etc/yum.repos.d/CentOS-Base.repo

sed -i -e "s/^#baseurl/baseurl/g" /etc/yum.repos.d/CentOS-AppStream.repo
sed -i -e "s/^mirrorlist/#mirrorlist/g" /etc/yum.repos.d/CentOS-AppStream.repo

sed -i -e "s/^#baseurl/baseurl/g" /etc/yum.repos.d/CentOS-PowerTools.repo
sed -i -e "s/^mirrorlist/#mirrorlist/g" /etc/yum.repos.d/CentOS-PowerTools.repo

sed -i -e "s/^#baseurl/baseurl/g" /etc/yum.repos.d/CentOS-Extras.repo
sed -i -e "s/^mirrorlist/#mirrorlist/g" /etc/yum.repos.d/CentOS-Extras.repo

sed -i -e "s/^#baseurl/baseurl/g" /etc/yum.repos.d/CentOS-centosplus.repo
sed -i -e "s/^mirrorlist/#mirrorlist/g" /etc/yum.repos.d/CentOS-centosplus.repo

rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial

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
retry dnf --quiet --assumeyes --enablerepo=extras install epel-release

sed -i -e "s/^#baseurl/baseurl/g" /etc/yum.repos.d/epel.repo
sed -i -e "s/^mirrorlist/#mirrorlist/g" /etc/yum.repos.d/epel.repo

rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-8

# Disable the testing repo.
sed --in-place "s/^/# /g" /etc/yum.repos.d/epel-testing.repo
sed --in-place "s/# #/##/g" /etc/yum.repos.d/epel-testing.repo

# Disable the playground repo.
sed --in-place "s/^/# /g" /etc/yum.repos.d/epel-playground.repo
sed --in-place "s/# #/##/g" /etc/yum.repos.d/epel-playground.repo

# Update the base install first.
retry dnf --assumeyes update

# Install the basic packages we'd expect to find.
# The whois package was removed from EPEL because it will be included with CentOS 8.2, when released.
# add whois
retry dnf --assumeyes install sudo dmidecode dnf-utils bash-completion man man-pages mlocate vim-enhanced bind-utils wget dos2unix unix2dos lsof telnet net-tools coreutils grep gawk sed curl patch sysstat make cmake libarchive autoconf automake libtool gcc-c++ libstdc++-devel gcc cpp ncurses-devel glibc-devel glibc-headers kernel-headers psmisc python36

if [ -f /etc/yum.repos.d/CentOS-Vault.repo.rpmnew ]; then
  rm --force /etc/yum.repos.d/CentOS-Vault.repo.rpmnew
fi

if [ -f /etc/yum.repos.d/CentOS-Media.repo.rpmnew ]; then
  rm --force /etc/yum.repos.d/CentOS-Media.repo.rpmnew
fi

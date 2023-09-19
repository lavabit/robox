#!/bin/bash

retry() {
  local COUNT=1
  local DELAY=0
  local RESULT=0
  while [[ "${COUNT}" -le 10 ]]; do
    [[ "${RESULT}" -ne 0 ]] && {
      [ "`which tput 2> /dev/null`" != "" ] && [ -n "$TERM" ] && tput setaf 1
      echo -e "\n${*} failed... retrying ${COUNT} of 10.\n" >&2
      [ "`which tput 2> /dev/null`" != "" ] && [ -n "$TERM" ] && tput sgr0
    }
    "${@}" && { RESULT=0 && break; } || RESULT="${?}"
    COUNT="$((COUNT + 1))"

    # Increase the delay with each iteration.
    DELAY="$((DELAY + 10))"
    sleep $DELAY
  done

  [[ "${COUNT}" -gt 10 ]] && {
    [ "`which tput 2> /dev/null`" != "" ] && [ -n "$TERM" ] && tput setaf 1
    echo -e "\nThe command failed 10 times.\n" >&2
    [ "`which tput 2> /dev/null`" != "" ] && [ -n "$TERM" ] && tput sgr0
  }

  return "${RESULT}"
}

error() {
  if [ $? -ne 0 ]; then
    printf "\n\napt failed...\n\n";
    exit 1
  fi
}

# To allow for automated installs, we disable interactive configuration steps.
export DEBIAN_FRONTEND=noninteractive
export DEBCONF_NONINTERACTIVE_SEEN=true

# We handle name server setup later, but for now, we need to ensure valid resolvers are available.
printf "nameserver 4.2.2.1\nnameserver 4.2.2.2\nnameserver 208.67.220.220\n" > /etc/resolv.conf

# If the apt configuration directory exists, we add our own config options.
if [ -d /etc/apt/apt.conf.d/ ]; then

# Disable periodic activities of apt.
printf "APT::Periodic::Enable \"0\";\n" >> /etc/apt/apt.conf.d/10periodic

# We disable APT retries, to avoid inconsistent error handling, as it only retries some errors. Instead we let the retry function detect, and retry a given command regardless of the error.
printf "APT::Acquire::Retries \"0\";\n" >> /etc/apt/apt.conf.d/20retries

fi

# Setup the source list.
cat <<-EOF > /etc/apt/sources.list
deb http://archive.debian.org/debian/ stretch main
deb http://archive.debian.org/debian-security/ stretch/updates main
EOF

# Keep the daily apt updater from deadlocking our installs.
systemctl stop apt-daily.service apt-daily.timer


## We tried updating the ca-certificate package but that didn't work. It seems that one
## these packages must also be updated:
##  apt apt-transport-https apt-utils busybox cron debian-archive-keyring dpkg e2fslibs e2fsprogs gzip
##  isc-dhcp-client isc-dhcp-common klibc-utils libapt-inst2.0 libapt-pkg5.0 libbsd0 libcomerr2 libcurl3-gnutls
##  libdns-export162 libelf1 libexpat1 libfreetype6 libgcrypt20 libgmp10 libgnutls30 libgssapi-krb5-2
##  libhogweed4 libisc-export160 libk5crypto3 libklibc libkrb5-3 libkrb5support0 libldap-2.4-2 libldap-common
##  liblz4-1 liblzma5 libnettle6 libnghttp2-14 libp11-kit0 libpam-systemd libpython3.5-minimal
##  libpython3.5-stdlib libsasl2-2 libsasl2-modules-db libsqlite3-0 libss2 libssh2-1 libssl1.0.2 libssl1.1
##  libsystemd0 libudev1 libx11-6 libx11-data login openssl passwd python-apt-common python3-apt python3-urllib3
##  python3.5 python3.5-minimal rsyslog sudo systemd systemd-sysv tar tzdata udev vim-common vim-tiny xxd zlib1g  

## Template for a manual package download and install.
# wget --quiet --no-check-certificate --output-document ca-certificates_20200601-deb9u2_all.deb "https://archive.debian.org/debian-security/pool/updates/main/c/ca-certificates/ca-certificates_20200601~deb9u2_all.deb"
# echo "6cb3ce4329229d71a6f06b9f13c710457c05a469012ea31853ac300873d5a3e1  ca-certificates_20200601-deb9u2_all.deb" | sha256sum -c || exit 1
# dpkg -i ca-certificates_20200601-deb9u2_all.deb 

# Ensure the server includes any necessary updates.
retry apt-get --assume-yes -o Dpkg::Options::="--force-confnew" update; error
retry apt-get --assume-yes -o Dpkg::Options::="--force-confnew" upgrade; error
retry apt-get --assume-yes -o Dpkg::Options::="--force-confnew" dist-upgrade; error

# Setup the source list to use HTTPS.
cat <<-EOF > /etc/apt/sources.list
deb http://archive.debian.org/debian/ stretch main
deb http://archive.debian.org/debian-security/ stretch/updates main
EOF

# The packages users expect on a sane system.
retry apt-get --assume-yes install vim net-tools mlocate psmisc; error

# The packages needed to compile magma.
retry apt-get --assume-yes install gcc g++ gawk gcc-multilib make autoconf automake libtool flex bison gdb valgrind valgrind-dbg libpython2.7 libc6-dev libc++-dev libncurses5-dev libmpfr4 libmpfr-dev patch make cmake libarchive13 libbsd-dev libsubunit-dev libsubunit0 pkg-config lsb-release; error

# The memcached server.
retry apt-get --assume-yes install memcached libevent-dev; error

# The postfix server for message relays.
retry apt-get --assume-yes install postfix postfix-cdb libcdb1 ssl-cert; error

# Need to retrieve the source code.
retry apt-get --assume-yes install git git-man liberror-perl rsync wget; error

# Needed to run the watcher and status scripts.
retry apt-get --assume-yes install sysstat inotify-tools; error

# Needed to run the stacie script.
retry apt-get --assume-yes install python-crypto python-cryptography; error

# Boosts the available entropy which allows magma to start faster.
retry apt-get --assume-yes install haveged; error

# Populate the mlocate database during boot.
printf "@reboot root command bash -c '/etc/cron.daily/mlocate'\n" > /etc/cron.d/mlocate

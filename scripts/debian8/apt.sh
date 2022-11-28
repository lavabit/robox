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
deb http://ftp.debian.org/debian/ jessie main
deb http://security.debian.org/debian-security jessie/updates main
deb http://ftp.debian.org/debian/ jessie-updates main
EOF

# Trick the system into using expired keys.
date -s 20200701

# Ensure the server includes any necessary updates.
retry apt-get --assume-yes -o Dpkg::Options::="--force-confnew" update; error
retry apt-get --assume-yes -o Dpkg::Options::="--force-confnew" upgrade; error
retry apt-get --assume-yes -o Dpkg::Options::="--force-confnew" dist-upgrade; error

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

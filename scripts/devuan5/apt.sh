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




#### NOTE: the sources.list file is modified by the preseed configuration to
#### use the archive server once the distro reaches end of life.



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

# Remove the CDROM as a media source.
sed -i -e "/cdrom:/d" /etc/apt/sources.list

# Ensure the server includes any necessary updates.
retry apt-get --assume-yes -o Dpkg::Options::="--force-confnew" update; error
retry apt-get --assume-yes -o Dpkg::Options::="--force-confnew" upgrade; error
retry apt-get --assume-yes -o Dpkg::Options::="--force-confnew" dist-upgrade; error

# The packages users expect on a sane system.
retry apt-get --assume-yes install vim mlocate psmisc rsync; error

# Populate the mlocate database during boot.
printf "@reboot root command bash -c '/etc/cron.daily/mlocate'\n" > /etc/cron.d/mlocate

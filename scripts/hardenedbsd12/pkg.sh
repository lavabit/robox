#!/bin/bash -x

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

# Configure fetch so it retries temporary failures.
export FETCH_RETRY=5
export FETCH_TIMEOUT=30
export ASSUME_ALWAYS_YES=yes

# Force the use of HTTPS for package updates.
mkdir -p /usr/local/etc/pkg/repos
cat <<-EOF > /usr/local/etc/pkg/repos/FreeBSD.conf

HardenedBSD: { 
 enabled: no
}

FreeBSD: { 
  url: "pkg+http://pkg.freebsd.org/\${ABI}/quarterly",
  manifests_archive = "packagesite";
  fingerprints: "/usr/share/keys/pkg",
  mirror_type: "srv",
  signature_type: "fingerprints",
  enabled: yes
}
EOF

retry pkg bootstrap
retry pkg-static update --force
retry pkg-static upgrade --yes --force

# Generic system utils.
retry pkg install --yes curl wget sudo bash gnuls gnugrep psmisc vim

# Since most scripts expect bash to be in the bin directory, create a symlink.
[ ! -f /bin/bash ] && [ -f  /usr/local/bin/bash ] && ln -s /usr/local/bin/bash /bin/bash
[ ! -f /usr/bin/bash ] && [ -f  /usr/local/bin/bash ] && ln -s /usr/local/bin/bash /usr/bin/bash

# Disable fortunate cookies.
sed -i -e "/fortune/d" /usr/share/skel/dot.login
sed -i -e "/fortune/d" /usr/share/skel/dot.profile
sed -i -e "/fortune/d" /usr/share/skel/dot.profile-e

sed -i -e "/fortune/d" /home/vagrant/.login
sed -i -e "/fortune/d" /home/vagrant/.profile

# Update the locate database.
/etc/periodic/weekly/310.locate

# Configure daily locate database updates.
echo '# 315.locate' >> /etc/periodic.conf
echo 'daily_locate_enable="YES" # Update locate daily' >> /etc/periodic.conf
cp /etc/periodic/weekly/310.locate /usr/local/etc/periodic/daily/315.locate
sed -i -e "s/weekly_locate_enable/daily_locate_enable=/g" /usr/local/etc/periodic/daily/315.locate

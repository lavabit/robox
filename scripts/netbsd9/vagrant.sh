#!/bin/bash -ux

retry() {
  local COUNT=1
  local RESULT=0
  while [[ "${COUNT}" -le 10 ]]; do
    [[ "${RESULT}" -ne 0 ]] && {
      [ "`which tput 2> /dev/null`" != "" ] && tput setaf 1
      echo -e "\\n${*} failed... retrying ${COUNT} of 10.\\n" >&2
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
    echo -e "\\nThe command failed 10 times.\\n" >&2
    [ "`which tput 2> /dev/null`" != "" ] && tput sgr0
  }

  return "${RESULT}"
}

# Ensure the pkg utilities are in the path.
export PATH="/usr/sbin/:/usr/pkg/bin/:$PATH"

# Dictate the package repository.
export PKG_PATH="http://ftp.netbsd.org/pub/pkgsrc/packages/NetBSD/amd64/9.2/All"

# Sudo should already be installed, but just in case.
retry pkg_add sudo

# Password hash.
PASSWORDHASH="$(pwhash vagrant)"

# Setup the vagrant group.
group add vagrant

# Setup the default user password and ensure the vagrant shell is bash.
user add -s /usr/pkg/bin/bash -d /home/vagrant -m -g vagrant -G wheel -p "$PASSWORDHASH" vagrant

# If needed, create the user home, and ssh subdirectory.
mkdir -pm 700 /home/vagrant/.ssh

cat <<-EOF > /usr/pkg/etc/sudoers.d/vagrant
vagrant ALL=(ALL) NOPASSWD: ALL
EOF
chmod 0440 /usr/pkg/etc/sudoers.d/vagrant

# Create the vagrant user ssh directory.
mkdir -pm 700 /home/vagrant/.ssh

# Create an authorized keys file and insert the insecure public vagrant key.
cat <<-EOF > /home/vagrant/.ssh/authorized_keys
ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEA6NF8iallvQVp22WDkTkyrtvp9eWW6A8YVr+kz4TjGYe7gHzIw+niNltGEFHzD8+v1I2YJ6oXevct1YeS0o9HZyN1Q9qgCgzUFtdOKLv6IedplqoPkcmF0aYet2PkEDo3MlTBckFXPITAMzF8dJSIFo9D8HfdOV0IAdx4O7PtixWKn5y2hMNG0zQPyUecp4pzC6kivAIhyfHilFR61RGL+GPXQ2MWZWFYbAGjyiYJnAmCP3NOTd0jMZEnDkbUvxhMmBYSdETk1rRgm+R4LOzFUGaHqHDLKLX+FIPKcF96hrucXzcWyLbIbEgE98OHlnVYCzRdK8jlqm8tehUc9c9WhQ== vagrant insecure public key
EOF

# Ensure the permissions are set correct to avoid OpenSSH complaints.
chmod 0600 /home/vagrant/.ssh/authorized_keys
chown -R vagrant:vagrant /home/vagrant/.ssh

# Create an empty bashrc file.
touch /home/vagrant/.bashrc

# Add logic to the shrc file that will read the bashrc if the shell is bash.
cat <<-EOF >> /home/vagrant/.shrc

if [ "\$SHELL" == "/usr/pkg/bin/bash" ] && [ -f \$HOME/.bashrc ]; then
	source \$HOME/.bashrc
fi

EOF

# Mark the vagrant box build time.
date > /etc/vagrant_box_build_time

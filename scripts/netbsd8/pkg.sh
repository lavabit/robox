#!/bin/sh

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

set -x

# Ensure the pkg utilities are in the path.
export PATH="/usr/sbin/:/usr/pkg/bin/:$PATH"

# Dictate the package repository.
export PKG_PATH="http://ftp.netbsd.org/pub/pkgsrc/packages/NetBSD/amd64/8.0/All"

# Add the packages.
retry pkg_add vim curl wget sudo bash pkgin slocate bash-completion

# Enable the binary package repositories.
sed -i 's,^[^#].*$,http://ftp.NetBSD.org/pub/pkgsrc/packages/NetBSD/$arch/8.0/All,' /usr/pkg/etc/pkgin/repositories.conf

# Link up the bash target so script headers work properly.
if [ ! -f /bin/bash ] && [ -f /usr/pkg/bin/bash ]; then
  ln -s /usr/pkg/bin/bash /bin/bash
fi

# Make bash the default shell.
chsh -s /usr/pkg/bin/bash root

# Setup the locate database.
cp /usr/pkg/share/examples/slocate/updatedb.conf /etc/updatedb.conf

# Create the database folder.
if [ ! -d /var/lib/ ]; then
  mkdir /var/lib/
fi

# Create the database folder.
if [ ! -d /var/lib/slocate/ ]; then
  mkdir /var/lib/slocate/
fi

# On some systems, the mtab file isn't created automatically, which causes
# spurious slocate errors.
if [ ! -f /etc/mtab ]; then
  touch /etc/mtab
fi

# Update the package database.
/usr/pkg/bin/updatedb

# Auto update the database.
printf "\n16 * * * * /usr/pkg/bin/updatedb\n" >> /var/cron/tabs/root

# Create an empty bashrc file.
touch $HOME/.bashrc

# Add logic to the shrc file that will read the bashrc if the shell is bash.
cat <<-EOF >> /root/.shrc

if [ "\$SHELL" == "/usr/pkg/bin/bash" ] && [ -f \$HOME/.bashrc ]; then
	source \$HOME/.bashrc
fi

EOF

# Make the path, and package repo variables persistent.
echo 'export PATH="/usr/sbin/:/usr/pkg/bin/:$PATH"' >> /etc/profile
echo 'export PKG_PATH="http://ftp.netbsd.org/pub/pkgsrc/packages/NetBSD/amd64/8.0/All"' >> /etc/profile

# Load the bash helpers.
echo 'source /usr/pkg/share/bash-completion/bash_completion' >> /etc/profile

# Reboot so everything initializes properly.
/sbin/shutdown -r +1 &

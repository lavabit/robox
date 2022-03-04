#!/bin/bash

error() {
        if [ $? -ne 0 ]; then
                printf "\n\nbase configuration script failure...\n\n";
                exit 1
        fi
}

# Check whether the install media is mounted, and if necessary mount it.
if [ ! -f /media/media.repo ]; then
  mount /dev/cdrom /media
fi

# Always use vim, even as root.
printf "alias vi vim\n" > /etc/profile.d/vim.csh
printf "# For bash/zsh, if no alias is already set.\nalias vi >/dev/null 2>&1 || alias vi=vim\n" > /etc/profile.d/vim.sh

# Setup the python path and increase the history size.
printf "export HISTSIZE=\"100000\"\n" > /etc/profile.d/histsize.sh
chcon "system_u:object_r:bin_t:s0" /etc/profile.d/histsize.sh
chmod 644 /etc/profile.d/histsize.sh

